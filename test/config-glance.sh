source ini-config.sh
function config_glance {
    local file=/etc/glance/glance-api.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT notification_driver  noop
        iniset -sudo $file DEFAULT verbose True
        iniset -sudo $file database connection mysql://glance:123@localhost/glance
        iniset -sudo $file keystone_authtoken auth_uri http://controller:5000/v2.0
        iniset -sudo $file keystone_authtoken identity_uri http://controller:35357
        iniset -sudo $file keystone_authtoken admin_tenant_name service
        iniset -sudo $file keystone_authtoken admin_user glance
        iniset -sudo $file keystone_authtoken admin_password 123
        iniset -sudo $file paste_deploy flavor keystone
        iniset -sudo $file glance_store default_store file
        iniset -sudo $file glance_store filesystem_store_datadir /var/lib/glance/images/
        echo
    else
        echo -e "== skip\n"
    fi

local file=/etc/glance/glance-registry.conf

    echo -e "** 修改 $file"
    if [[ true ]]; then
        echo -e "== 修改 ..."
        iniset -sudo $file DEFAULT notification_driver  noop
        iniset -sudo $file DEFAULT verbose True
        iniset -sudo $file database connection mysql://glance:123@localhost/glance
        iniset -sudo $file keystone_authtoken auth_uri http://controller:5000/v2.0
        iniset -sudo $file keystone_authtoken identity_uri http://controller:35357
        iniset -sudo $file keystone_authtoken admin_tenant_name service
        iniset -sudo $file keystone_authtoken admin_user glance
        iniset -sudo $file keystone_authtoken admin_password 123
        iniset -sudo $file paste_deploy flavor keystone
        echo
    else
        echo -e "== skip\n"
    fi

}

config_glance
