function install_keystone {
    install_service_package keystone "Keystone" openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached
    return $?
}

function config_apache_conf {
    local file=/etc/httpd/conf/httpd.conf
    head3 "修改 $file"


    local conf_needed=$(is_needed_reconf $file)

    if [[ $(grep "^ServerName" $file) == '' ||
                $conf_needed == 'yes' ]]; then
        local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
        sed -i "/^ServerName/d" $file
        sed -i "/^#ServerName/{s/$/\nServerName $hostname/;:f;n;b f;}" $file
        text "完成"
    else
        text "已完成"
    fi

    # create /etc/httpd/conf.d/wsgi-keystone.conf
    file=/etc/httpd/conf.d/wsgi-keystone.conf
    head3 "创建 $file"
    conf_needed=$(is_needed_reconf $file)

    if [[ $(is_file_exist $file) == 'no' || $conf_needed == 'yes' ]]; then
        cp -u $TOP_DIR/files/wsgi-keystone.conf $file
        text "完成"
    else
        text "已完成"
    fi
}

function config_apache_wsgi {
    local KEYSTONE_WSGI_DIR=/var/www/cgi-bin/keystone

    # config mod_wsgi
    if [[ ! -d $KEYSTONE_WSGI_DIR ]]; then
        mkdir -p $KEYSTONE_WSGI_DIR
    fi

    local file=$KEYSTONE_WSGI_DIR/main
    head3 "创建 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $(is_file_exist $file) == 'no' || $conf_needed == 'yes' ]]; then
        cp -u $TOP_DIR/files/keystone.py $file
        text "完成"
    else
        text "已完成"
    fi

    file=$KEYSTONE_WSGI_DIR/admin
    head3 "创建 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $(is_file_exist $file) == 'no' || $conf_needed == 'yes' ]]; then
        cp -u $TOP_DIR/files/keystone.py $file
        text "完成"
    else
        text "已完成"
    fi
    chown keystone:keystone  $KEYSTONE_WSGI_DIR/admin $KEYSTONE_WSGI_DIR/admin
    chmod 755 $KEYSTONE_WSGI_DIR/main $KEYSTONE_WSGI_DIR/admin
    chown -R keystone:keystone $KEYSTONE_WSGI_DIR
    chmod 755 $KEYSTONE_WSGI_DIR/*
}

function config_apache {
    head2 "配置 Apache2"
    # edit /etc/httpd/conf/httpd.conf
    config_apache_conf

    # config wsgi
    config_apache_wsgi

    # auto start apache
    local KEYSTONE_WSGI_DIR=/var/www/cgi-bin/keystone
    local file=/etc/httpd/conf/httpd.conf
    local file1=/etc/httpd/conf.d/wsgi-keystone.conf
    local file2=${KEYSTONE_WSGI_DIR}/main
    local file3=${KEYSTONE_WSGI_DIR}/admin


    local need_restart=$(is_needed_restart_service $file $file1 $file2 $file3)

    start_service httpd $needed_restart
}

function config_keystone_conf {
    local file=/etc/keystone/keystone.conf
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)
    local token=$(iniget $CONF_FILE $NODE_TYPE ADMIN_TOKEN)
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == 'yes' ]]; then
        iniset $file DEFAULT verbose True
        iniset $file DEFAULT admin_token $token

        local url=mysql://keystone:$pass@$hostname/keystone
        iniset $file database connection $url

        iniset $file memcache servers localhost:11211

        iniset $file token provider keystone.token.providers.uuid.Provider
        iniset $file token driver keystone.token.persistence.backends.memcache.Token

        iniset $file revoke driver keystone.contrib.revoke.backends.sql.Revoke
        text "完成"
    else
        text "已完成"
    fi
}

function config_keystone {
    # auto start memcached
    local need_restart=$([[ $(is_local_conf_changed) == yes ||
                                  $(is_local_conf_changed) == new ]] &&
                             echo hard || echo no)
    start_service memcached $need_restart

    # edit /etc/keystone/keystone.conf
    config_keystone_conf

    # populate database

    local file=/etc/keystone/keystone.conf

    local need_populate=$(is_needed_reconf $file)
    # create database
    [[ $need_populate == yes ]] && drop_database keystone
    create_database keystone
    populate_database keystone $need_populate

    # config httpd mod_wsgi
    config_apache

    # auto start keystone
    # is_needed_restart keystone $file
    # local needed_restart=$?
    # start_service openstack-keystone $needed_restart 1
}

function verify_keystone {
    # verify conf file
    head2 "检查修改后的配置文件"

    local file=/etc/keystone/keystone.conf
    local file1=/etc/httpd/conf.d/wsgi-keystone.conf

    verify_conf_file $file
    verify_conf_file $file1

    # verify
    head2 "检查 Keystone 服务是否正常"

    local need_verify=$(is_needed_verify_service $file $file1)

    if [[ $need_verify == 'yes' ]]; then
        source_admin_openrc

        head3 "Admin Project"
        local cmd='openstack token issue'
        text -n "$cmd"
        $cmd

        echo

        local cmd='openstack project list'
        text -n "$cmd"
        $cmd
        echo

        cmd='openstack user list'
        text -n "$cmd"
        $cmd
        echo

        cmd='openstack role list'
        text -n "$cmd"
        $cmd
        echo

        head3 "Demo Project"
        source_demo_openrc
        cmd='openstack token issue'
        text -n "$cmd"
        $cmd
        echo

        cmd='openstack project list'
        text -n "$cmd"
        $cmd
        cecho -r "您使用的" -g -B "Demo" -B -r "账户无权查看" -B -g "project list"
        echo
    else
        text "正常"
    fi
}

function deploy_keystone {
    if [[ $NODE_TYPE == 'controller' ]]; then
        head1 "部署 Keystone"
        MAGIC=_keystone-${NODE_TYPE}
        install_keystone
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_keystone
            #new_env_run "create_account"
            create_account
            verify_keystone
            iniset $NODE_FILE state keystone done
        fi
    fi
}

function create_account {
    # configure prerequisites
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)

    # create keystone service entity and API endpoint
    head2 "创建 Keystone Service & Endpoints"

    config_keystone_openrc

    while [[ $(openstack project list; echo $?) != 0 ]]; do
        ((RETRY_TIMES++))
        if [[ $RETRY_TIMES == $RETRY_TIMES_MAX ]]; then
            RETRY_TIMES=0
            perror "Keystone服务无法正常使用， 无奈退出！"
            exit 1
        fi
        systemctl restart httpd
    done

    create_service keystone "OpenStack Identity" identity

    create_endpoint keystone RegionOne identity --publicurl http://${hostname}:5000/v2.0 --internalurl http://${hostname}:5000/v2.0 --adminurl http://${hostname}:35357/v2.0

    # create projects, users, and roles
    head2 "创建 Project, User, Roles"

    create_project admin  "Admin Project"

    local pass=$(iniget $CONF_FILE $NODE_TYPE ADMIN_PASS)

    create_user_role admin $pass admin

    openstack_role_add admin admin admin

    head2 "创建 Project Service"

    create_project service "Service Project"

    head2 "创建 Project Demo"

    create_project demo "Demo Project"

    local pass=$(iniget $CONF_FILE $NODE_TYPE DEMO_PASS)
    create_user_role demo $pass user

    openstack_role_add demo demo user
}
