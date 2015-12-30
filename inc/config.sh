function start_service {
    local service=$1
    local restart_type=$2
    local opt='--no-block'
    head2 "启动/重启 $service"

    local service_exist=$(systemctl list-unit-files|grep $service.service)
    if [[ $service_exist != '' ]]; then
        local is_enabled=$(systemctl is-enabled $service)
        if [[ $is_enabled != 'enabled' ]]; then
            systemctl -q enable $service.service
        fi
        case $restart_type in
            soft)
                local is_active=$( systemctl is-active $service)
                if [[ $is_active == 'active' ]]; then
                    text "已启动 [ $restart_type ]"
                else
                    systemctl $opt start $service.service
                    systemctl status $service.service
                    echo
                    sleep 3
                fi
                ;;
            mixed)
                systemctl -q disable $service.service
                systemctl $opt restart $service.service
                systemctl status $service.service
                echo
                sleep 3;;
            hard)
                systemctl $opt restart $service.service
                systemctl status $service.service
                echo
                sleep 3;;
            *)
            ;;
        esac
        # check if service started success
        local is_failed=$(systemctl is-failed $service)
        local is_active=$(systemctl is-active $service)
        if [[ $is_failed == 'failed' ||
                    $is_failed == 'inactive' ]]; then
            systemctl $opt restart $service.service
            systemctl status $service.service
            echo
            text "已启动 [ $is_active ], but [ $is_failed ]"
            sleep 3
        else
            text "已启动 [ $restart_type ], but [ $is_failed ]"
        fi
    else
        text "无此服务"
    fi
}

function drop_database {
    local service=$1
    local dbpass=$(iniget $CONF_FILE controller DATABASE_PASS)
    local exist=$(mysql -s -uroot -p$dbpass -hlocalhost -e "show databases;"|grep $service)
    if [[ $exist != '' ]]; then
        mysql -uroot -p$dbpass -hlocalhost -e "DROP DATABASE $service;"
    fi
}

function create_database {
    local service=$1

    local dbpass=$(iniget $CONF_FILE controller DATABASE_PASS)
    local pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local exist=$(mysql -s -uroot -p$dbpass -hlocalhost -e "show databases;"|grep $service)

    head2 "创建 $service 数据库"

    if [[ $exist == '' ]]; then
         mysql -uroot -p$dbpass -hlocalhost -e "CREATE DATABASE $service;"

         mysql -uroot -p$pass -hlocalhost -e "GRANT ALL PRIVILEGES ON $service.* TO '$service'@'localhost' IDENTIFIED BY '$pass';"

         mysql -uroot -p$pass -hlocalhost -e "GRANT ALL PRIVILEGES ON $service.* TO '$service'@'%' IDENTIFIED BY '$pass';"
        text "完成"
    else
        text "已完成"
    fi
}

function populate_database {
    local service=$1
    local is_needed_populate=$2

    local dbpass=$(iniget $CONF_FILE controller DATABASE_PASS)
    local pass=$(iniget $CONF_FILE controller SERVICE_PASS)
    local exist=$(mysql -s -uroot -p$dbpass -hlocalhost -e "use $service;show tables")

    head2 "初始化数据库"

    if [[ $is_needed_populate == 'yes' || $exist == '' ]]; then
        if [[ $service == 'nova' ||
                    $service == 'cinder' ]]; then
            su -s /bin/bash -c "${service}-manage db sync" $service
        elif [[ $service == 'neutron' ]]; then
            su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
        else
            su -s /bin/bash -c "${service}-manage db_sync" $service
        fi
        text "完成"
    else
        text "已完成"
    fi
}

function is_needed_reconf {
    local file=$1

    if [[ $(is_file_exist $file) == 'no' ]]; then
        echo yes
        return
    fi
    # backup file
    local backup=${file}${MAGIC}_bak
    [[ $(is_file_exist $backup) == 'no' ]] && cp -a $file $backup

    # 判断服务配置文件是否改变，若是人为修改，则不应重新配置为默认的配置
    # 若不是人为修改，则定是脚本修改，此时应根据什么判断其被修改了呢
    local conf_file_changed=$(is_file_changed $file)

    # 判断 local.conf文件是否改变，
    local local_conf_changed=$(is_local_conf_changed)

    # 若用户强制安装，则肯定会覆盖用户修改的且脚本也需要修改的参数
    local conf_forced=$(is_force_enabled config)

    # is_file_changed若返回yes，则是用户修改的，则不应将用户修改的配置重新修改成默认的
    if [[ $(is_file_exist $file) == 'no' ||
                $conf_file_changed == 'new' ||
                $local_conf_changed == 'new' ||  $local_conf_changed == 'yes' ||
                $conf_forced == 'yes' ]]; then
        echo yes
    else
        echo no
    fi
}
