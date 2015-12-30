function install_neutron {
    local ret=0
    if [[ $NODE_TYPE == 'controller' ]]; then
        install_service_package neutron "Neutron Controller" openstack-neutron openstack-neutron-ml2 python-neutronclient which
        ret=$?
    elif [[ $NODE_TYPE == 'compute' ]]; then
        install_service_package neutron "Neutron Compute" openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch
        ret=$?
    elif [[ $NODE_TYPE == 'network' ]]; then
        install_service_package neutron "Neutron Network" openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch
        ret=$?
    fi
    return $ret
}

function create_neutron_controller_account {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)

    head2 "创建 Neutron Service & Endpoint"

    source_admin_openrc

    create_user neutron $pass
    openstack_role_add service neutron admin

    create_service neutron "OpenStack Networking" network

    create_endpoint neutron RegionOne network --publicurl http://$hostname:9696 --adminurl http://$hostname:9696 --internalurl http://$hostname:9696
}

function config_neutron_controller_conf {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local neutron_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local nova_pass=$neutron_pass
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local ip=$(iniget $CONF_FILE controller IP)

    local file=/etc/neutron/neutron.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file database connection mysql://neutron:$neutron_pass@$hostname/neutron

        iniset $file DEFAULT rpc_backend rabbit

        iniset $file oslo_messaging_rabbit rabbit_host $hostname
        iniset $file oslo_messaging_rabbit rabbit_userid $rabbit_user
        iniset $file oslo_messaging_rabbit rabbit_password $rabbit_pass

        iniset $file DEFAULT auth_strategy keystone

        inicomment $file keystone_authtoken identity_uri
        inicomment $file keystone_authtoken admin_tenant_name
        inicomment $file keystone_authtoken admin_user
        inicomment $file keystone_authtoken admin_password

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username neutron
        iniset $file keystone_authtoken password $neutron_pass

        iniset $file DEFAULT core_plugin ml2
        iniset $file DEFAULT service_plugins router
        iniset $file DEFAULT allow_overlapping_ips True
        iniset $file DEFAULT notify_nova_on_port_status_changes True
        iniset $file DEFAULT notify_nova_on_port_data_changes True
        iniset $file DEFAULT nova_url http://$hostname:8774/v2

        iniset $file nova auth_url http://$hostname:35357
        iniset $file nova auth_plugin password
        iniset $file nova project_domain_id default
        iniset $file nova user_domain_id default
        iniset $file nova region_name RegionOne
        iniset $file nova project_name service
        iniset $file nova username nova
        iniset $file nova password $nova_pass

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/neutron/plugins/ml2/ml2_conf.ini

    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file ml2 type_drivers flat,vlan,gre,vxlan
        iniset $file ml2 tenant_network_types gre
        iniset $file ml2 mechanism_drivers openvswitch

        iniset $file ml2_type_gre tunnel_id_ranges 1:1000

        iniset $file securitygroup enable_security_group True
        iniset $file securitygroup enable_ipset True
        iniset $file securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/nova/nova.conf
    head2 "修改 $file"

    local metadata_secret=$(iniget $CONF_FILE controller METADATA_SECRET)

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file DEFAULT network_api_class nova.network.neutronv2.api.API
        iniset $file DEFAULT security_group_api neutron
        iniset $file DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        iniset $file DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

        iniset $file neutron url http://$hostname:9696
        #crudini --set $file neutron auth_strategy keystone
        iniset $file neutron auth_strategy keystone
        iniset $file neutron admin_auth_url http://$hostname:35357/v2.0
        iniset $file neutron admin_tenant_name service
        iniset $file neutron admin_username neutron
        iniset $file neutron admin_password $neutron_pass
        # needed by neutron network-node configuration
        iniset $file neutron service_metadata_proxy True
        iniset $file neutron metadata_proxy_shared_secret $metadata_secret
        text "完成"
    else
        text "已完成"
    fi
    [[ -L /etc/neutron/plugin.ini ]] || ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
}

function start_neutron_controller {
    local need_restart=$1
    # restart compute service
    start_service openstack-nova-api $need_restart
    start_service openstack-nova-scheduler $need_restart
    start_service openstack-nova-conductor $need_restart

    start_service neutron-server $need_restart
}

function config_neutron_controller {
    # create database
    create_database neutron

    # create the service credentials
    create_neutron_controller_account

    # edit /etc/neutron/neutron.conf, /etc/nova/nova.conf,
    #      /etc/neutron/plugins/ml2/ml2_conf.ini
    config_neutron_controller_conf

    # populate database
    local file=/etc/neutron/neutron.conf
    local file1=/etc/neutron/plugins/ml2/ml2_conf.ini
    local file2=/etc/nova/nova.conf


    local need_populate=$(is_needed_reconf $file $file1 $file2)

    populate_database neutron $need_populate

    # auto start
    local need_restart=$(is_needed_restart_service $file $file1 $file2)
    start_neutron_controller $need_restart
}

function config_neutron_network_conf_sysctl {
    local file=/etc/sysctl.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        if [[ $(grep "^net.ipv4.ip_forward=1" $file) == '' ]]; then
            sed -i '$a net.ipv4.ip_forward=1\nnet.ipv4.conf.all.rp_filter=0\nnet.ipv4.conf.default.rp_filter=0' $file
        fi
        text "完成"
    else
        text "已完成"
    fi
    sysctl -p > /dev/null
}

function config_neutron_network_conf {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local neutron_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local nova_pass=$neutron_pass
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local network_ip
    if [[ $SUB_NODE_TYPE == allin1 ]]; then
        network_ip=$(iniget $CONF_FILE controller IP)
    else
        network_ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    fi
    local metadata_secret=$(iniget $CONF_FILE controller METADATA_SECRET)

    # edit /etc/neutron/neutron.conf
    local file=/etc/neutron/neutron.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        inicomment $file database connection

        iniset $file DEFAULT rpc_backend rabbit

        iniset $file oslo_messaging_rabbit rabbit_host $hostname
        iniset $file oslo_messaging_rabbit rabbit_userid $rabbit_user
        iniset $file oslo_messaging_rabbit rabbit_password $rabbit_pass

        iniset $file DEFAULT auth_strategy keystone

        inicomment $file keystone_authtoken identity_uri
        inicomment $file keystone_authtoken admin_tenant_name
        inicomment $file keystone_authtoken admin_user
        inicomment $file keystone_authtoken admin_password

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username neutron
        iniset $file keystone_authtoken password $neutron_pass

        iniset $file DEFAULT core_plugin ml2
        iniset $file DEFAULT service_plugins router
        iniset $file DEFAULT allow_overlapping_ips True

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/neutron/plugins/ml2/ml2_conf.ini

    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file ml2 type_drivers flat,vlan,gre,vxlan
        iniset $file ml2 tenant_network_types gre
        iniset $file ml2 mechanism_drivers openvswitch

        iniset $file ml2_type_flat flat_networks external
        iniset $file ml2_type_gre tunnel_id_ranges 1:1000

        iniset $file securitygroup enable_security_group True
        iniset $file securitygroup enable_ipset True
        iniset $file securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

        iniset $file ovs local_ip $network_ip
        iniset $file ovs bridge_mappings external:br-ex

        iniset $file agent tunnel_types gre
        text "完成"
    else
        text "已完成"
    fi

    local file=/etc/neutron/l3_agent.ini
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        iniset $file DEFAULT external_network_bridge
        iniset $file DEFAULT router_delete_namespaces True
        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/neutron/dhcp_agent.ini
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        iniset $file DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
        iniset $file DEFAULT dhcp_delete_namespaces True
        iniset $file DEFAULT verbose True

        iniset $file DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/neutron/dnsmasq-neutron.conf
    head2 "修改 $file"

    [[ -e $file ]] || touch $file

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        echo 'dhcp-option-force 26,1454' > $file
        text "完成"
    else
        text "已完成"
    fi

    pkill dnsmasq

    file=/etc/neutron/metadata_agent.ini
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file DEFAULT auth_uri http://$hostname:5000
        iniset $file DEFAULT auth_url http://$hostname:35357
        iniset $file DEFAULT auth_region RegionOne
        iniset $file DEFAULT auth_plugin password
        iniset $file DEFAULT project_domain_id default
        iniset $file DEFAULT user_domain_id default
        iniset $file DEFAULT project_name service
        iniset $file DEFAULT username neutron
        iniset $file DEFAULT password $neutron_pass
        iniset $file DEFAULT nova_metadata_ip $hostname
        iniset $file DEFAULT metadata_proxy_shared_secret $metadata_secret
        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi
}

function start_neutron_network {
    local need_restart=$1
    start_service openvswitch $need_restart

    #add_br_ex

    systemctl daemon-reload
    start_service neutron-openvswitch-agent $need_restart

    start_service neutron-l3-agent $need_restart
    start_service neutron-dhcp-agent $need_restart
    start_service neutron-metadata-agent $need_restart

    systemctl enable neutron-ovs-cleanup.service > /dev/null
}

function config_neutron_network {
    # edit conf file
    config_neutron_network_conf

    # auto start
    local file=/etc/neutron/neutron.conf
    local file1=/etc/neutron/plugins/ml2/ml2_conf.ini
    local file2=/etc/neutron/l3_agent.ini
    local file3=/etc/neutron/dhcp_agent.ini
    local file4=/etc/neutron/dnsmasq-neutron.conf
    local file5=/etc/neutron/metadata_agent.ini

    local need_restart=$(is_needed_restart_service $file $file1 $file2 $file3 $file4 $file5)

    # finalize
    local file=/etc/neutron/plugin.ini
    [[ -L $file ]] || ln -s /etc/neutron/plugins/ml2/ml2_conf.ini $file

    file=/usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
    [[ -e $file ]] || cp -u /usr/lib/systemd/system/neutron-openvswitch-agent.service $file

    file=/usr/lib/systemd/system/neutron-openvswitch-agent.service

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' $file
        make_sha1_file $file
    fi

    start_neutron_network $need_restart
}

function config_neutron_compute_conf_sysctl {
    local file=/etc/sysctl.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        if [[ $(grep "^net.ipv4.conf.all.rp_filter=0" $file) == '' ]]; then
            sed -i '$a net.ipv4.conf.all.rp_filter=0\nnet.ipv4.conf.default.rp_filter=0\nnet.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1' $file
        fi
        text "完成"
    else
        text "已完成"
    fi
    sysctl -p > /dev/null
}

function config_neutron_compute_conf {
    local file=/etc/neutron/neutron.conf
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local neutron_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local nova_pass=$neutron_pass
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local compute_ip=
    if [[ $SUB_NODE_TYPE == allin1 ]]; then
        compute_ip=$(iniget $CONF_FILE controller IP)
    else
        compute_ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    fi
    local metadata_secret=$(iniget $CONF_FILE controller METADATA_SECRET)

    local file=/etc/neutron/neutron.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        inicomment $file database connection

        iniset $file DEFAULT rpc_backend rabbit

        iniset $file oslo_messaging_rabbit rabbit_host $hostname
        iniset $file oslo_messaging_rabbit rabbit_userid $rabbit_user
        iniset $file oslo_messaging_rabbit rabbit_password $rabbit_pass

        iniset $file DEFAULT auth_strategy keystone

        inicomment $file keystone_authtoken identity_uri
        inicomment $file keystone_authtoken admin_tenant_name
        inicomment $file keystone_authtoken admin_user
        inicomment $file keystone_authtoken admin_password

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username neutron
        iniset $file keystone_authtoken password $neutron_pass

        iniset $file DEFAULT core_plugin ml2
        iniset $file DEFAULT service_plugins router
        iniset $file DEFAULT allow_overlapping_ips True

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/neutron/plugins/ml2/ml2_conf.ini
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file ml2 type_drivers flat,vlan,gre,vxlan
        iniset $file ml2 tenant_network_types gre
        iniset $file ml2 mechanism_drivers openvswitch

        iniset $file ml2_type_gre tunnel_id_ranges 1:1000

        iniset $file securitygroup enable_security_group True
        iniset $file securitygroup enable_ipset True
        iniset $file securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

        iniset $file ovs local_ip $compute_ip

        iniset $file agent tunnel_types gre
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/nova/nova.conf
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset  $file DEFAULT network_api_class nova.network.neutronv2.api.API
        iniset  $file DEFAULT security_group_api neutron
        iniset  $file DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        iniset  $file DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

        iniset  $file neutron url http://$hostname:9696
        iniset  $file neutron auth_strategy keystone
        iniset  $file neutron admin_auth_url http://$hostname:35357/v2.0
        iniset  $file neutron admin_tenant_name service
        iniset  $file neutron admin_username neutron
        iniset  $file neutron admin_password $neutron_pass
        text "完成"
    else
        text "已完成"
    fi
}

function start_neutron_compute {
    local need_restart=$1
    start_service openvswitch $need_restart
    start_service openstack-nova-compute $need_restart
    start_service neutron-openvswitch-agent $need_restart
}

function config_neutron_compute {
    config_neutron_compute_conf

    # auto start
    local file=/etc/neutron/neutron.conf
    local file1=/etc/neutron/plugins/ml2/ml2_conf.ini
    local file2=/etc/nova/nova.conf

    local need_restart=$(is_needed_restart_service $file $file1 $file2)

    # finalize
    [[ -L /etc/neutron/plugin.ini ]] || ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

    local file3=/usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
    [[ -e $file3 ]] || cp /usr/lib/systemd/system/neutron-openvswitch-agent.service $file3

    sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
        /usr/lib/systemd/system/neutron-openvswitch-agent.service

    start_neutron_compute $need_restart
}

function config_neutron {
    if [[ $NODE_TYPE == 'controller' ]]; then
        config_neutron_controller
    elif [[ $NODE_TYPE == 'compute' ]]; then
        config_neutron_compute
    elif [[ $NODE_TYPE == 'network' ]]; then
        config_neutron_network
    fi
}

function verify_neutron {
    # verify conf file
    head2 "检查修改后的配置文件"

    if [[ $NODE_TYPE == 'controller' ]]; then
        local file=/etc/neutron/neutron.conf
        local file1=/etc/neutron/plugins/ml2/ml2_conf.ini
        local file2=/etc/nova/nova.conf

        verify_conf_file $file
        verify_conf_file $file1
        verify_conf_file $file2

        head2 "检查 Neutron 服务是否正常"
        local need_verify=$(is_needed_verify_service $file $file1 $file2)

        if [[ $need_verify == yes ]]; then
            source_admin_openrc
            local cmd='neutron ext-list'
            text -n "检查 Neutron Extenstion List：$cmd"
            $cmd
            echo

            local host1=$(iniget $CONF_FILE network HOSTNAME)
            local host2=$(iniget $CONF_FILE compute HOSTNAME)
            if [[ $(is_host_reachable $host1) == yes ||
                        $(is_host_reachable $host2) == yes ]]; then
                local cmd='neutron agent-list'
                text -n "检查 Neutron Agent List：$cmd"
                $cmd
                echo
            fi
        else
            text "正常"
        fi
    else
        if [[ $NODE_TYPE == 'network' ]]; then
            local file=/etc/sysctl.conf
            local file0=/etc/neutron/neutron.conf
            local file1=/etc/neutron/plugins/ml2/ml2_conf.ini
            local file2=/etc/neutron/l3_agent.ini
            local file3=/etc/neutron/dhcp_agent.ini
            local file4=/etc/neutron/dnsmasq-neutron.conf
            local file5=/etc/neutron/metadata_agent.ini

            verify_conf_file $file
            verify_conf_file $file0
            verify_conf_file $file1
            verify_conf_file $file2
            verify_conf_file $file3
            verify_conf_file $file4
            verify_conf_file $file5

            is_needed_verify_service $file $file0 $file1 $file2 $file3 $file4 $file5 > /dev/null
        else
            local file=/etc/sysctl.conf
            local file1=/etc/neutron/neutron.conf
            local file2=/etc/neutron/plugins/ml2/ml2_conf.ini
            local file3=/etc/nova/nova.conf

            verify_conf_file $file
            verify_conf_file $file1
            verify_conf_file $file2
            verify_conf_file $file3

            is_needed_verify_service $file $file1 $file2 $file3 > /dev/null
        fi
        head2 "检查 Neutron [$NODE_TYPE] 服务是否正常"
        local ip=$(iniget $CONF_FILE controller IP)
        cecho -b "请使用浏览打开地址：" -g "http://$ip/dashboard" -n
    fi
}

function deploy_neutron {
    if  [[ $NODE_TYPE == 'network' || $NODE_TYPE == 'compute' ||
                 $NODE_TYPE == 'controller' ]]; then
        head1 "部署 Neutron $NODE_TYPE"

        MAGIC=_neutron-${NODE_TYPE}

        if [[ $NODE_TYPE == 'network' ]]; then
            config_neutron_network_conf_sysctl
        elif [[ $NODE_TYPE == 'compute' ]]; then
            config_neutron_compute_conf_sysctl
        fi

        install_neutron
        local install_success=$?

        if [[ $install_success == 1 ]]; then
            config_neutron
            verify_neutron
            iniset $NODE_FILE state neutron done
        fi
    fi
}

function add_br_ex {
    ovs-vsctl add-br br-ex; service network restart
    sleep 2
    ovs-vsctl add-port br-ex $(get_nth_ifdev 2)
    sleep 2

}

function create_neutron_network {
    local external_network_cidr=$(iniget $CONF_FILE controller EXTERNAL_NETWORK_CIDR)
    local external_network_gateway=$(iniget $CONF_FILE controller EXTERNAL_NETWORK_GATEWAY)
    local floating_ip_start=$(iniget $CONF_FILE controller FLOATING_IP_START)
    local floating_ip_end=$(iniget $CONF_FILE controller FLOATING_IP_END)
    source_admin_openrc
    neutron net-create ext-net --router:external \
            --provider:physical_network external \
            --provider:network_type flat

    neutron subnet-create ext-net $external_network_cidr \
            --name ext-subnet \
            --allocation-pool \
            start=$floating_ip_start,end=$floating_ip_end \
            --disable-dhcp --gateway $external_network_gateway

    local tenant_network_cidr=$(iniget $CONF_FILE controller TENANT_NETWORK_CIDR)
    local dns_resolver=$(iniget $CONF_FILE controller DNS_RESOLVER)
    local tenant_network_gateway=$(iniget $CONF_FILE controller TENANT_NETWORK_GATEWAY)
    source_demo_openrc
    neutron net-create demo-net
    neutron subnet-create demo-net $tenant_network_cidr \
            --name demo-subnet --dns-nameserver $dns_resolver \
            --gateway $tenant_network_gateway

    neutron router-create demo-router
    neutron router-interface-add demo-router demo-subnet
    neutron router-gateway-set demo-router ext-net
}
