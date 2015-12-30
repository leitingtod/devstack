source ini-config.sh
function config_controllor {
    local file=/etc/neutron/neutron.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file database connection mysql://neutron:123@controllor/neutron
        iniset -sudo $file DEFAULT rpc_backend rabbit
        iniset -sudo $file oslo_messaging_rabbit rabbit_host controllor
        iniset -sudo $file oslo_messaging_rabbit rabbit_userid openstack
        iniset -sudo $file oslo_messaging_rabbit rabbit_password 123
        iniset -sudo $file DEFAULT auth_strategy keystone
        iniset -sudo $file keystone_authtoken auth_uri http://controllor:5000
        iniset -sudo $file keystone_authtoken auth_url http://controllor:35357
        iniset -sudo $file keystone_authtoken auth_plugin password
        iniset -sudo $file keystone_authtoken project_domain_id default
        iniset -sudo $file keystone_authtoken user_domain_id default
        iniset -sudo $fiel keystone_authtoken project_name service  
        iniset -sudo $file keystone_authtoken username neutron
        iniset -sudo $file keystone_authtoken password 123
        iniset -sudo $file DEFAULT core_plugin ml2
        iniset -sudo $file DEFAULT service_plugins router
        iniset -sudo $file DEFAULT allow_overlapping_ips True
        iniset -sudo $file DEFAULT notify_nova_on_port_status_changes True
        iniset -sudo $file DEFAULT notify_nova_on_port_data_changes True
        iniset -sudo $file DEFAULT nova_url http://controllor:8774/v2 
        iniset -sudo $file nova auth_url http://controllor:35357
        iniset -sudo $file nova auth_plugin password
        iniset -sudo $file nova project_domain_id default
        iniset -sudo $file nova user_domain_id default
        iniset -sudo $file nova region_name RegionOne
        iniset -sudo $file nova project_name service
        iniset -sudo $file nova username nova
        iniset -sudo $file nova password 123
        iniset -sudo $file DEFAULT verbose True
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/plugins/ml2/ml2_conf.ini

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file ml2 type_drivers flat,gre
        iniset -sudo $file ml2 tenant_network_types gre
        iniset -sudo $file ml2 mechanism_drivers openvswitc
        iniset -sudo $file ml2_type_gre tunnel_id_ranges 1:1000
        iniset -sudo $file securitygroup enable_security_group True
        iniset -sudo $file securitygroup enable_ipset True
        iniset -sudo $file securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
        echo
    else
        echo -e "== skip\n"
    fi
    
    local file=/etc/nova/nova.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT network_api_class nova.network.neutronv2.api.API
        iniset -sudo $file DEFAULT security_group_api neutron
        iniset -sudo $file DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        iniset -sudo $file DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
        iniset -sudo $file neutron url http://controller:9696
        iniset -sudo $file neutron auth_strategy keystone
        iniset -sudo $file neutron admin_auth_url http://controller:35357/v2.0
        iniset -sudo $file neutron admin_tenant_name service
        iniset -sudo $file neutron admin_username neutron
        iniset -sudo $file neutron admin_password 123
        echo
    else
        echo -e "== skip\n"
    fi
}

config_controllor

function config_network {
    local file=/etc/neutron/neutron.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset sudo $file DEFAULT rpc_backend rabbit
        iniset -sudo $file oslo_messaging_rabbit rabbit_host controller
        iniset -sudo $file oslo_messaging_rabbit rabbit_userid openstack
        iniset -sudo $file oslo_messaging_rabbit rabbit_password 123
        iniset -sudo $file DEFAULT auth_strategy keystone
        iniset -sudo $file keystone_authtoken auth_uri http://controllor:5000
        iniset -sudo $file keystone_authtoken auth_url http://controllor:35357
        iniset -sudo $file keystone_authtoken auth_plugin password
        iniset -sudo $file keystone_authtoken project_domain_id default
        iniset -sudo $file keystone_authtoken user_domain_id default
        iniset -sudo $fiel keystone_authtoken project_name service
        iniset -sudo $file keystone_authtoken username neutron
        iniset -sudo $file keystone_authtoken password 123
        iniset -sudo $file DEFAULT core_plugin ml2
        iniset -sudo $file DEFAULT service_plugins router
        iniset -sudo $file DEFAULT allow_overlapping_ips True
        iniset -sudo $file DEFAULT verbose True
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/plugins/ml2/ml2_conf.ini

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file ml2 type_drivers flat,vlan,gre,vxlan
        iniset -sudo $file ml2 tenant_network_types gre
        iniset -sudo $file ml2 mechanism_drivers openvswitc
        iniset -sudo $file ml2_type_flat flat_networks external
        iniset -sudo $file ml2_type_gre tunnel_id_ranges 1:1000
        iniset -sudo $file securitygroup enable_security_group True
        iniset -sudo $file securitygroup enable_ipset True
        iniset -sudo $file securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
        iniset -sudo $file ovs bridge_mappings external:br-ex
        iniset -sudo $file ovs local_ip neutron
        iniset -sudo $file agent tunnel_types gre
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/l3_agent.ini
    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        iniset -sudo $file DEFAULT external_network_bridge br-ex
        iniset -sudo $file DEFAULT router_delete_namespaces True
        iniset -sudo $file DEFAULT verbose True
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/dhcp_agent.ini

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
        iniset -sudo $file DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
        iniset -sudo $file DEFAULT dhcp_delete_namespaces True
        iniset -sudo $file DEFAULT verbose True
        iniset -sudo $file DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/dnsmasq-neutron.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT dhcp-option-force 26,1454
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/metadata_agent.ini

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT auth_uri http://controller:5000
        iniset -sudo $file DEFAULT auth_url http://controller:35357
        iniset -sudo $file DEFAULT auth_region RegionOne
        iniset -sudo $file DEFAULT auth_plugin password
        iniset -sudo $file DEFAULT project_domain_id default
        iniset -sudo $file DEFAULT user_domain_id default
        iniset -sudo $file DEFAULT project_name service
        iniset -sudo $file DEFAULT username neutron
        iniset -sudo $file DEFAULT password 123
        iniset -sudo $file DEFAULT nova_metadata_ip controller
        iniset -sudo $file DEFAULT verbose True
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/nova/nova.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file neutron service_metadata_proxy True
        echo
    else
        echo -e "== skip\n"
    fi
}

config_network

function config_compute {
    local file=/etc/neutron/neutron.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT rpc_backend rabbit
        iniset -sudo $file oslo_messaging_rabbit rabbit_host controllor
        iniset -sudo $file oslo_messaging_rabbit rabbit_userid openstack
        iniset -sudo $file oslo_messaging_rabbit rabbit_password 123
        iniset -sudo $file DEFAULT auth_strategy keystone
        iniset -sudo $file keystone_authtoken auth_uri http://controllor:5000
        iniset -sudo $file keystone_authtoken auth_url http://controllor:35357
        iniset -sudo $file keystone_authtoken auth_plugin password
        iniset -sudo $file keystone_authtoken project_domain_id default
        iniset -sudo $file keystone_authtoken user_domain_id default
        iniset -sudo $fiel keystone_authtoken project_name service
        iniset -sudo $file keystone_authtoken username neutron
        iniset -sudo $file keystone_authtoken password 123
        iniset -sudo $file DEFAULT core_plugin ml2
        iniset -sudo $file DEFAULT service_plugins router
        iniset -sudo $file DEFAULT allow_overlapping_ips True
        iniset -sudo $file DEFAULT verbose True

        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/neutron/plugins/ml2/ml2_conf.ini

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file ml2 type_drivers flat,gre
        iniset -sudo $file ml2 tenant_network_types gre
        iniset -sudo $file ml2 mechanism_drivers openvswitc
        iniset -sudo $file ml2_type_gre tunnel_id_ranges 1:1000
        iniset -sudo $file securitygroup enable_security_group True
        iniset -sudo $file securitygroup enable_ipset True
        iniset -sudo $file securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
        iniset -sudo $file ovs bridge_mappings external:br-ex
        iniset -sudo $file ovs local_ip neutron
        iniset -sudo $file agent tunnel_types gre
        echo
    else
        echo -e "== skip\n"
    fi

    local file=/etc/nova/nova.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT network_api_class nova.network.neutronv2.api.API
        iniset -sudo $file DEFAULT security_group_api neutron
        iniset -sudo $file DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
        iniset -sudo $file DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
        iniset -sudo $file neutron url http://controller:9696
        iniset -sudo $file neutron auth_strategy keystone
        iniset -sudo $file neutron admin_auth_url http://controller:35357/v2.0
        iniset -sudo $file neutron admin_tenant_name service
        iniset -sudo $file meutron admin_username neutron
        iniset -sudo $file neutron admin_password 123
        echo
    else
        echo -e "== skip\n"
    fi

}

config_compute

