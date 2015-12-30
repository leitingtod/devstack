source ini-config.sh
function config_controller {
    local file=/etc/nova/nova.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file database connection  mysql://nova:123@controller/nova
        iniset -sudo $file DEFAULT rpc_backend  rabbit
    iniset -sudo $file DEFAULT rabbit_host  controller
    iniset -sudo $file DEFAULT auth_strategy  keystone
    iniset -sudo $file DEFAULT rabbit_password  123
    iniset -sudo $file oslo_messaging_rabbit rpc_backend  rabbit
        iniset -sudo $file oslo_messaging_rabbit rabbit_host  controller
        iniset -sudo $file oslo_messaging_rabbit rabbit_password  123
    iniset -sudo $file DEFAULT network_api_class  nova.network.neutronv2.api.API
    iniset -sudo $file DEFAULT security_group_api  neutron
    iniset -sudo $file DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver
    iniset -sudo $file DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
    iniset -sudo $file DEFAULT my_ip  controller
    iniset -sudo $file DEFAULT vncserver_listen  controller
    iniset -sudo $file DEFAULT vncserver_proxyclient_address  controller
    iniset -sudo $file DEFAULT verbose  True
    iniset -sudo $file keystone_authtoken auth_uri  http://controller:5000/v2.0
    iniset -sudo $file keystone_authtoken identity_uri  http://controller:35357
    iniset -sudo $file keystone_authtoken admin_tenant_name  service
    iniset -sudo $file keystone_authtoken admin_user  nova
    iniset -sudo $file keystone_authtoken admin_password  123
    iniset -sudo $file glance host  controller
    iniset -sudo $file neutron url  http://controller:9696
    iniset -sudo $file neutron auth_strategy  keystone
    iniset -sudo $file neutron admin_auth_url  http://controller:35357/v2.0
    iniset -sudo $file neutron admin_tenant_name  service
    iniset -sudo $file neutron admin_username  neutron
    iniset -sudo $file neutron admin_password  123
    iniset -sudo $file neutron service_metadata_proxy  True
        echo
    else
        echo -e "== 已完成\n"
    fi
}



function config_compute {
    local file=/etc/nova/nova.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT rpc_backend  rabbit
        iniset -sudo $file DEFAULT rabbit_host  controller
        iniset -sudo $file DEFAULT rabbit_password  123
        iniset -sudo $file oslo_messaging_rabbit rpc_backend  rabbit
        iniset -sudo $file oslo_messaging_rabbit rabbit_host  controller
        iniset -sudo $file oslo_messaging_rabbit rabbit_password  123
        iniset -sudo $file DEFAULT network_api_class  nova.network.neutronv2.api.API
        iniset -sudo $file DEFAULT security_group_api  neutron
    iniset -sudo $file DEFAULT auth_strategy  keystone
        iniset -sudo $file DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver
        iniset -sudo $file DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
        iniset -sudo $file DEFAULT my_ip  compute
    iniset -sudo $file DEFAULT vnc_enabled  True
        iniset -sudo $file DEFAULT vncserver_listen  0.0.0.0
        iniset -sudo $file DEFAULT vncserver_proxyclient_address  compute
    iniset -sudo $file DEFAULT novncproxy_base_url  http://controller:6080/vnc_auto.html
        iniset -sudo $file DEFAULT verbose  True
        iniset -sudo $file keystone_authtoken auth_uri  http://controller:5000/v2.0
        iniset -sudo $file keystone_authtoken identity_uri  http://controller:35357
        iniset -sudo $file keystone_authtoken admin_tenant_name  service
        iniset -sudo $file keystone_authtoken admin_user  nova
        iniset -sudo $file keystone_authtoken admin_password  123
        iniset -sudo $file glance host  controller
        iniset -sudo $file neutron url  http://controller:9696
        iniset -sudo $file neutron auth_strategy  keystone
        iniset -sudo $file neutron admin_auth_url  http://controller:35357/v2.0
        iniset -sudo $file neutron admin_tenant_name  service
        iniset -sudo $file neutron admin_username  neutron
        iniset -sudo $file neutron admin_password  123
        echo
    else
        echo -e "== 已完成\n"
    fi
}

if [[ $1 == '1' ]]; then
    config_compute
else
    config_controller
fi
