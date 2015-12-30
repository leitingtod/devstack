function install_glance {
    install_service_package glance "Glance" openstack-glance python-glance python-glanceclient
    return $?
}

function config_glance_conf {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)
    local url=mysql://glance:$pass@$hostname/glance

    local file=/etc/glance/glance-api.conf
    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == 'yes' ]]; then
        iniset $file DEFAULT notification_driver noop
        iniset $file DEFAULT verbose True

        iniset $file database connection $url

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username glance
        iniset $file keystone_authtoken password $pass

        iniset $file paste_deploy flavor keystone

        iniset $file glance_store default_store file
        iniset $file glance_store filesystem_store_datadir /var/lib/glance/images/
        text "完成"
    else
        text "已完成"
    fi

    file=/etc/glance/glance-registry.conf
    head2 "修改 $file"

    conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == 'yes' ]]; then
        iniset $file DEFAULT notification_driver noop
        iniset $file DEFAULT verbose True

        iniset $file database connection $url

        iniset $file keystone_authtoken auth_uri http://$hostname:5000
        iniset $file keystone_authtoken auth_url http://$hostname:35357
        iniset $file keystone_authtoken auth_plugin password
        iniset $file keystone_authtoken project_domain_id default
        iniset $file keystone_authtoken user_domain_id default
        iniset $file keystone_authtoken project_name service
        iniset $file keystone_authtoken username glance
        iniset $file keystone_authtoken password $pass

        iniset $file paste_deploy flavor keystone
        text "完成"
    else
        text "已完成"
    fi
}

function create_glance_account {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)

    head2 "创建 Glance Service & Endpoint"

    source_admin_openrc

    create_user glance $pass
    openstack_role_add service glance admin

    create_service glance "OpenStack Image service" image

    create_endpoint glance RegionOne image --publicurl http://$hostname:9292 --internalurl http://$hostname:9292 --adminurl http://$hostname:9292
}

function start_glance {
    local need_restart=$1
    start_service openstack-glance-api $need_restart
    start_service openstack-glance-registry $need_restart
}

function config_glance {
    # create database
    create_database glance

    # create the service credentials
    create_glance_account

    # edit /etc/glance/glance-api.conf, /etc/glance/glance-registry.conf
    config_glance_conf

    # populate databas
    local file=/etc/glance/glance-api.conf
    local file1=/etc/glance/glance-registry.conf

    local need_populate=$(is_needed_reconf glance $file $fil1)

    populate_database glance $need_populate

    # auto start
    local need_restart=$(is_needed_restart_service $file $file1)
    start_glance $need_restart
}

function verify_glance {
    # verify conf file
    head2 "检查修改后的配置文件"

    local file=/etc/glance/glance-api.conf
    local file1=/etc/glance/glance-registry.conf

    verify_conf_file $file
    verify_conf_file $file1

    # verify service
    head2 "检查 Glance 服务是否正常"

    local need_verify=$(is_needed_verify_service $file $file1)

    if [[ $need_verify == 'yes' ]]; then

        [[ -d /tmp/images ]] || mkdir /tmp/images
        cd /tmp/images
        [[ -f cirros-0.3.1-x86_64-disk.img ]] || cp $TOP_DIR/files/cirros-0.3.1-x86_64-disk.img .
        cd $TOP_DIR
        source_admin_openrc

        head3 "添加 Glance 镜像"
        local image_name=cirros-0.3.1-x86_64

        if [[ $(is_image_exist $image_name) == 'yes' ]]; then
            text "已创建"
        else
            head3 "glance image-create --name \"cirros-0.3.1-x86_64\" --disk-format qcow2 --container-format bare --visibility public --file /tmp/images/cirros-0.3.1-x86_64-disk.img --progress"

            glance image-create --name "cirros-0.3.1-x86_64" --disk-format qcow2 --container-format bare --visibility public --file /tmp/images/cirros-0.3.1-x86_64-disk.img
            echo
        fi
        head3 "查看镜像列表：glance image-list"
        glance image-list
        echo
    else
        text "正常"
    fi
}

function deploy_glance {
    if [[ $NODE_TYPE == 'controller' ]]; then
        head1 "部署 Glance "
        MAGIC=_glance-${NODE_TYPE}
        install_glance
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_glance
            verify_glance
            iniset $NODE_FILE state glance done
        fi
    fi
}
