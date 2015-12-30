function install_horizon {
    install_service_package horizon "OpenStack Horizon" openstack-dashboard httpd mod_wsgi memcached python-memcached
    return $?
}

function config_horizon {
    # edit /etc/openstack-dashboard/local_settings
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local file=/etc/openstack-dashboard/local_settings

    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        local tab='    '
        local str="CACHES = {\n$tab'default': {\n$tab$tab'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\n$tab$tab'LOCATION': '127.0.0.1:11211',\n$tab}\n}\n"
        sed -i "/^CACHES/,/^}/c ${str}" $file
        sed -i "s|\("^OPENSTACK_HOST" * *\).*|\1= \"$hostname\"|" $file
        sed -i "s|\("^ALLOWED_HOSTS" * *\).*|\1= \"*\"|" $file
        sed -i "s|\("^OPENSTACK_KEYSTONE_DEFAULT_ROLE" * *\).*|\1= \"user\"|" $file
        text "完成"
    else
        text "已完成"
    fi

    # finalize
    # setsebool -P httpd_can_network_connect on
    if [[ $(cat /etc/passwd|cut -f 1 -d:|grep apache) != '' &&
        -d /usr/share/openstack-dashboard/static ]]; then
        chown -R apache:apache /usr/share/openstack-dashboard/static
    fi

    local need_restart=$(is_needed_restart_service $file)

    start_service memcached $need_restart
    start_service httpd $need_restart
    sleep 5
    local ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    if [[ $(curl -s http://$ip/dashboard|grep 404) != '' ]]; then
        systemctl restart httpd.service
    fi
}

function verify_horizon_conf {
    grep "^OPENSTACK_HOST" $file
    grep "^ALLOWED_HOSTS" $file
    grep "^OPENSTACK_KEYSTONE_DEFAULT_ROLE" $file
    sed -n "/^CACHES/,/^}/p" $file
    echo
}

function verify_horizon {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local file=/etc/openstack-dashboard/local_settings
    head2 "检查修改过的配置文件"

    verify_conf_file $file verify_horizon_conf
    is_needed_verify_service $file > /dev/null

    head2 "检查 Horizon 服务是否可用"
    local ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    cecho -b "请使用浏览打开地址：" -g "http://$ip/dashboard" -n
}

function deploy_horizon {
    if [[ $NODE_TYPE == 'controller' ]]; then
        head1 "部署 OpenStack Dashboard"
        MAGIC=_horizon-${NODE_TYPE}
        install_horizon
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_horizon
            verify_horizon
        fi
    fi
}
