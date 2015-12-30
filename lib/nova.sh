function install_nova {
    local ret=0
    if [[ $NODE_TYPE == 'controller' ]]; then
        install_service_package nova "Nova Controller" openstack-nova-api openstack-nova-cert \
                                openstack-nova-console openstack-nova-conductor \
                                openstack-nova-novncproxy openstack-nova-scheduler \
                                python-novaclient
        ret=$?
    elif [[ $NODE_TYPE == 'compute' ]]; then
        install_service_package nova "Nova Compute" openstack-nova-compute sysfsutils
        ret=$?
    fi
    return $ret
}

function create_nova_controller_account {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)

    head2 "创建 Nova Service & Endpoint"

    source_admin_openrc

    create_user nova $pass
    openstack_role_add service nova admin

    create_service nova "OpenStack Compute" compute

    create_endpoint nova RegionOne compute --publicurl http://$hostname:8774/v2/%\(tenant_id\)s --internalurl http://$hostname:8774/v2/%\(tenant_id\)s --adminurl http://$hostname:8774/v2/%\(tenant_id\)s
}

function config_nova_controller_conf {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local nova_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local ip=$(iniget $CONF_FILE controller IP)
    local file=/etc/nova/nova.conf

    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file database connection mysql://nova:$nova_pass@$hostname/nova

        iniset $file DEFAULT rpc_backend rabbit

        iniset $file oslo_messaging_rabbit rabbit_host $hostname
        iniset $file oslo_messaging_rabbit rabbit_userid $rabbit_user
        iniset $file oslo_messaging_rabbit rabbit_password $rabbit_pass

        iniset $file DEFAULT auth_strategy keystone

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username nova
        iniset $file keystone_authtoken password $nova_pass

        iniset $file DEFAULT my_ip $ip
        iniset $file DEFAULT vncserver_listen $ip
        iniset $file DEFAULT vncserver_proxyclient_address $ip

        iniset $file glance host $hostname

        iniset $file oslo_concurrency lock_path /var/lib/nova/tmp

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi
}

function start_nova_controller {
    local need_restart=$1
    start_service openstack-nova-api $need_restart
    start_service openstack-nova-cert $need_restart
    start_service openstack-nova-consoleauth $need_restart
    start_service openstack-nova-scheduler $need_restart
    start_service openstack-nova-conductor $need_restart
    start_service openstack-nova-novncproxy $need_restart

}

function config_nova_controller {
    # create database
    create_database nova

    # create the service credentials
    create_nova_controller_account

    # edit /etc/nova/nova.conf
    config_nova_controller_conf

    # populate database
    local file=/etc/nova/nova.conf

    local need_populate=$(is_needed_reconf $file)
    populate_database nova $need_populate

    # auto start
    local need_restart=$(is_needed_restart_service $file)
    start_nova_controller $need_restart
}

function config_nova_compute_conf {
    local file=/etc/nova/nova.conf
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local nova_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local controller_ip=$(iniget $CONF_FILE controller IP)
    local compute_ip=
    if [[ $SUB_NODE_TYPE == allin1 ]]; then
        compute_ip=$(iniget $CONF_FILE controller IP)
    else
        compute_ip=$(iniget $CONF_FILE compute IP)
    fi

    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        # kilo
        iniset $file DEFAULT rpc_backend rabbit

        iniset $file oslo_messaging_rabbit rabbit_host $hostname
        iniset $file oslo_messaging_rabbit rabbit_userid $rabbit_user
        iniset $file oslo_messaging_rabbit rabbit_password $rabbit_pass

        iniset $file DEFAULT auth_strategy keystone

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username nova
        iniset $file keystone_authtoken password $nova_pass

        iniset $file DEFAULT my_ip $compute_ip

        iniset $file DEFAULT vnc_enabled True
        iniset $file DEFAULT vncserver_listen 0.0.0.0
        iniset $file DEFAULT vncserver_proxyclient_address $compute_ip
        iniset $file DEFAULT novncproxy_base_url http://$controller_ip:6080/vnc_auto.html

        iniset $file glance host $hostname

        iniset $file oslo_concurrency lock_path /var/lib/nova/tmp

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi
}

function start_nova_compute {
    local need_restart=$1
    start_service libvirtd $need_restart
    # this will run a long time, so give it a timeout :-( don't know how to do
    #start_service openstack-nova-compute no-block
    # the true cause is nova-compute will wait until communicated to nova-conductor
    start_service openstack-nova-compute $need_restart
}

function config_nova_compute {
    # edit /etc/nova/nova.conf
    config_nova_compute_conf

    # finalize installation
    if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == 0 ]]; then
        iniset /etc/nova/nova.conf libvirt virt_type qemu
    fi

    # auto start
    local need_restart=$(is_needed_restart_service $file)
    start_nova_compute $need_restart
}

function config_nova {
    if [[ $NODE_TYPE == 'controller' ]]; then
        config_nova_controller
    elif [[ $NODE_TYPE == 'compute' ]]; then
        #update_environment > $TOP_DIR/files/parent-env.sh
        #bash -c "source $TOP_DIR/files/parent-env.sh; config_nova_compute"
        config_nova_compute
    fi
}

function verify_nova {
    # verify conf file
    local file=/etc/nova/nova.conf
    head2 "检查修改后的配置文件"
    verify_conf_file $file

    # verify service
    local need_verify=$(is_needed_verify_service $file)

    [[ $NODE_TYPE == compute ]] && head2 "检查 Nova Compute 服务是否正常" ||
            head2 "检查 Nova 服务是否正常"

    if [[ $need_verify == yes ]]; then
        if [[ $NODE_TYPE == 'controller' ]]; then
            source_admin_openrc
            local cmd='nova service-list'
            text -n "检查服务列表：$cmd"
            $cmd
            echo

            cmd='nova endpoints'
            text -n "检查API端点列表：$cmd"
            $cmd
            echo

            cmd='nova image-list'
            text -n "检查镜像列表：$cmd"
            $cmd
            echo
        elif [[ $NODE_TYPE == 'compute' ]]; then
            local ip=$(iniget $CONF_FILE controller IP)
            cecho -b "请使用浏览打开地址：" -g "http://$ip/dashboard" -n
        fi
    else
        text "正常"
    fi
}

function deploy_nova {
    if [[ $NODE_TYPE == 'controller' || $NODE_TYPE == 'compute' ]]; then
        [[ $NODE_TYPE == 'controller' ]] && head1 "部署 Nova" || head1 "部署 Nova Compute"

        MAGIC=_nova-${NODE_TYPE}

        install_nova
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_nova
            verify_nova
            iniset $NODE_FILE state nova done
        fi
    fi
}
