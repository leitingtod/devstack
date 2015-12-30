function install_mysql {
    install_service_package database "MariaDB" mariadb mariadb-server MySQL-python
    return $?
}

function config_mysql_conf {
    local file=/etc/my.cnf.d/mariadb_openstack.cnf

    head1 "创建 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == 'yes' ]]; then
        local ip=$(iniget $CONF_FILE $NODE_TYPE IP)
        cp -u $TOP_DIR/files/mariadb_openstack.cnf $file
        iniset $file mysqld bind-address $ip
        text "完成"
    else
        text "已完成"
    fi
}

function conf_mysql_secure_installation {
    local pass=$(iniget $CONF_FILE $NODE_TYPE DATABASE_PASS)

    if [[ $(systemctl is-active mariadb) == 'active' ]]; then
        mysql_secure_installation_auto $pass
    else
        ((RETRY_TIMES++))
        if [[ $RETRY_TIMES == $RETRY_TIMES_MAX ]]; then
            RETRY_TIMES=0
            perror "启动数据库失败， 无奈退出！"
            exit 1
        fi
        systemctl restart mariadb > /dev/null
        conf_mysql_secure_installation
    fi
}

function config_mysql {
    # create or edit /etc/my.cnf.d/mariadb_openstack.cnf
    config_mysql_conf

    # auto start mysql
    local file=/etc/my.cnf.d/mariadb_openstack.cnf
    local need_restart=$(is_needed_restart_service $file)

    start_service mariadb $need_restart

    head2 "设置 MariaDB 数据库安全参数"
    conf_mysql_secure_installation
    text "完成"
}

function verify_mysql {
    head2 "检查修改后的配置文件"
    local file=/etc/my.cnf.d/mariadb_openstack.cnf
    verify_conf_file $file

    head2 "检查 DATABASE 服务是否正常"
    local need_verify=$(is_needed_verify_service $file)

    if [[ $need_verify == 'yes' ]]; then
        local pass=$(iniget $CONF_FILE $NODE_TYPE DATABASE_PASS)
        text -n "查看数据库列表： show databases"
        mysql -uroot -p$pass -hlocalhost -e "show databases;"
        echo
    else
        text "已完成"
    fi
}

function deploy_database {
    if [[ $NODE_TYPE == 'controller' ]]; then
        head1 "部署 DataBase"
        MAGIC=_database-${NODE_TYPE}
        install_mysql
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_mysql
            verify_mysql
            iniset $NODE_FILE state database done
        fi
    fi
}
