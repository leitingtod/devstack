function install_cinder {
    local ret=0
    if [[ $NODE_TYPE == 'controller' ]]; then
        install_service_package cinder "Cinder" openstack-cinder python-cinderclient python-oslo-db
        ret=$?
    elif [[ $NODE_TYPE == 'cinder' ]]; then
        install_service_package cinder "Cinder" qemu lvm2 openstack-cinder targetcli python-oslo-db python-oslo-log MySQL-python
        ret=$?
    fi
    return $ret
}

function create_cinder_controller_account {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local pass=$(iniget $CONF_FILE $NODE_TYPE SERVICE_PASS)

    head2 "创建 Cinder Service & Endpoint"

    source_admin_openrc

    create_user cinder $pass
    openstack_role_add service cinder admin

    create_service cinder "OpenStack Block Storage" volume
    create_service cinderv2 "OpenStack Block Storage" volumev2

    create_endpoint cinder RegionOne volume --publicurl http://$hostname:8776/v2/%\(tenant_id\)s --internalurl http://$hostname:8776/v2/%\(tenant_id\)s --adminurl http://$hostname:8776/v2/%\(tenant_id\)s

     create_endpoint cinder RegionOne volumev2 --publicurl http://$hostname:8776/v2/%\(tenant_id\)s --internalurl http://$hostname:8776/v2/%\(tenant_id\)s --adminurl http://$hostname:8776/v2/%\(tenant_id\)s
}

function config_cinder_controller_conf {
    local file=/etc/cinder/cinder.conf
    [[ -e $file ]] || cp /usr/share/cinder/cinder-dist.conf $file
    chown -R cinder:cinder /etc/cinder/cinder.conf

    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local cinder_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local ip=$(iniget $CONF_FILE controller IP)
    local file=/etc/cinder/cinder.conf

   head2 "修改 $file"

   local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file database connection mysql://cinder:$cinder_pass@$hostname/cinder

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
        iniset $file keystone_authtoken username cinder
        iniset $file keystone_authtoken password $cinder_pass

        iniset $file DEFAULT my_ip $ip

        iniset $file oslo_concurrency lock_path /var/lock/cinder

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi
}

function start_cinder_controller {
    local need_restart=$1
    start_service openstack-cinder-api $need_restart
    start_service openstack-cinder-scheduler $need_restart
}

function config_cinder_controller {
    # create database
    create_database cinder

    # create the service credentials
    create_cinder_controller_account

    # edit /etc/cinder/cinder.conf
    config_cinder_controller_conf

    # populate database
    local file=/etc/cinder/cinder.conf

    local need_populate=$(is_needed_reconf $file)

    populate_database cinder $need_populate

    # auto start
    local need_restart=$(is_needed_restart_service $file)
    start_cinder_controller $need_restart
}

function config_cinder_blockstorage_conf {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local cinder_pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local rabbit_pass=$(iniget $CONF_FILE controller RABBIT_PASS)
    local rabbit_user=$(iniget $CONF_FILE controller RABBIT_USER)
    local cinder_ip=

    if [[ $SUB_NODE_TYPE == allin1 ]]; then
        cinder_ip=$(iniget $CONF_FILE controller IP)
    else
        cinder_ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    fi
    local file=/etc/cinder/cinder.conf

    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == yes ]]; then
        iniset $file database connection mysql://cinder:$cinder_pass@$hostname/cinder

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
        iniset $file keystone_authtoken username cinder
        iniset $file keystone_authtoken password $cinder_pass

        iniset $file DEFAULT my_ip $cinder_ip

        iniset $file lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
        iniset $file lvm volume_group cinder-volumes
        iniset $file lvm iscsi_protocol iscsi
        iniset $file lvm iscsi_helper lioadm

        iniset $file DEFAULT enabled_backends lvm
        iniset $file DEFAULT glance_host $hostname

        iniset $file oslo_concurrency lock_path /var/lock/cinder

        iniset $file DEFAULT verbose True
        text "完成"
    else
        text "已完成"
    fi
}

function start_cinder_blockstorage {
    local need_restart=$1
    start_service openstack-cinder-volume $need_restart
    start_service target $need_restart
}

function config_cinder_blockstorage {
    # auto start
    start_service lvm2-lvmetad soft

    head2 "创建 LVM physical volume"
    local disks=$(get_unused_disk)
    local vg='cinder-volumes'

    if [[ $disks == '' && $(lsblk|grep disk|wc -l) < 2 ]]; then
        perror "仅发现一块磁盘 /dev/$(lsblk)，请添加新的磁盘！"
        exit
    fi

    for volume in $disks; do
        # I only fdisk a new partion, so I hardcode /dev/vdb1
        local partion=/dev/${volume}1

        head3 "创建分区 /dev/${volume}1"
        if [[ $(is_partion_exist /dev/$volume) == no ]]; then
            fdisk_to_lvm /dev/$volume > /dev/null
            text "完成"
        else
            text "已完成"
        fi

        head3 "创建 LVM physical volume $partion"
        if [[ $(is_pv_exist $partion) == no ]]; then
            # pvcreate on a part
            pvcreate $partion
            text "完成"
        else
            text "已完成"
        fi

        if [[ $(is_vgroup_exist $vg) == no ]]; then
            head3 "创建 LVM volume group: $vg $partion"
        else
            head3 "扩展 LVM volume group: $vg $partion"
        fi

        if [[ $(is_vgroup_exist $vg) == no ]]; then
            vgcreate $vg $partion
            text "完成"
        else
            if [[ $(is_pv_in_vg $partion $vg) == no ]]; then
                vgextend $vg $partion
                text "完成"
            else
                text "已完成"
            fi
        fi
    done

    # edit file
    [ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder
    chown -R cinder:cinder /var/lock/cinder

    config_cinder_blockstorage_conf

    # auto start
    local file=/etc/cinder/cinder.conf

    local need_restart=$(is_needed_restart_service $file)
    start_cinder_blockstorage $need_restart
}

function config_cinder {
    if [[ $NODE_TYPE == 'controller' ]]; then
        config_cinder_controller
    elif [[ $NODE_TYPE == 'cinder' ]]; then
        config_cinder_blockstorage
    fi
    config_lvm_conf
}

function verify_lvm_conf {
    sed -n "/^devices/,/^}/p" $file|grep -v "#"|grep "[^$]"|highlight --src-lang=ini -O ansi
    echo
}

function verify_cinder {
    head2 "检查修改后的配置文件"
    local file=/etc/cinder/cinder.conf
    local file1=/etc/lvm/lvm.conf

    verify_conf_file $file
    verify_conf_file $file1 verify_lvm_conf

    local need_verify=$(is_needed_verify_service $file $file1)

    if [[ $NODE_TYPE == 'controller' ]]; then
        head2 "检查 Cinder 服务是否正常"

        if [[ $need_verify == yes ]]; then
            source_admin_openrc
            local cmd='cinder service-list'
            head3 "检查 Cinder Service List：$cmd"
            $cmd
            echo

            cmd='cinder list'
            head3 "查看存储块列表：$cmd"
            $cmd
            echo

            # local host=$(iniget $CONF_FILE cinder HOSTNAME)

            # if [[ $(is_host_reachable $host) == yes ]]; then
            #     source_demo_openrc

            #     local volume=demo-volume1
            #     local cmd='cinder create --name demo-volume1 1'
            #     head3 "创建 1GB 的存储块：$cmd"
            #     if [[ $(is_cinder_volume_exist $volume) == yes ]]; then
            #         text "已创建"
            #     else
            #         text -n "$cmd"
            #         $cmd
            #         echo
            #     fi

            #     local cmd='cinder list'
            #     head3 "查看存储块列表：$cmd"
            #     $cmd
            #     echo
            # fi
        else
            text "正常"
        fi
    else
        head2 "检查 Cinder 服务是否正常"
        local ip=$(iniget $CONF_FILE controller IP)
        cecho -b "请使用浏览打开地址：" -g "http://$ip/dashboard" -n
    fi
}

function deploy_cinder {
    if [[ $NODE_TYPE == 'controller' || $NODE_TYPE == 'cinder' ]]; then
        [[ $NODE_TYPE == 'controller' ]] && head1 "部署 Cinder Controller" ||
                head1 "部署 Cinder Block Storage"

        MAGIC=_cinder-${NODE_TYPE}

        install_cinder

        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_cinder
            verify_cinder
            iniset $NODE_FILE state cinder done
        fi
    fi
}
