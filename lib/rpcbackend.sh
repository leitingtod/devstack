function install_rabbitmq {
    install_service_package rpcbackend "RabbitMq" rabbitmq-server
    return $?
}

function create_rabbitmq_account {
    head2 "配置 RabbitMq"
    local users=$(rabbitmqctl list_users)
    local user=$(iniget $CONF_FILE $NODE_TYPE RABBIT_USER)
    local pass=$(iniget $CONF_FILE $NODE_TYPE RABBIT_PASS)
    local exist=`awk -v "STR=$users" -v "SUB=$user" '{print index(STR,SUB)}' <<<""`

    local ret=0
    if [[ $(systemctl is-active rabbitmq-server) == 'active' ]]; then
        if [[ $(rabbitmqctl status|grep Error) != "" ]]; then
            cecho -r "RabbitMq服务不正常，退出！"
            exit 1
        fi
        if [[ $exist == 0 ]]; then
             rabbitmqctl add_user $user $pass
             rabbitmqctl set_permissions $user ".*" ".*" ".*"
            text "完成"
            ret=1
        else
            text "已完成"
        fi
    fi
    return $ret
}

function config_rabbitmq {
    # auto start
    local need_restart=$([[ $(is_local_conf_changed) == yes ||
                                  $(is_local_conf_changed) == new ]] &&
                             echo hard || echo no)

    start_service rabbitmq-server $need_restart

    # add user and user's permittion
    create_rabbitmq_account
    return $?
}

function verify_rabbitmq {
    head2 "检查 RPCBACKEND 服务是否正常"

    local need_verify=$(is_needed_verify_service)

    if [[ $need_verify == 'yes' || $1 == 1 ]]; then
        text "检查用户列表：rabbitmqctl list_users"
        rabbitmqctl list_users
        echo

        if [[ $(rabbitmqctl list_users|grep Error) != '' ]]; then
            cecho -r "请关闭命令行窗口，重新打开执行！"
            exit 1
        fi

        text "检查服务器状态：rabbitmqctl status"
        rabbitmqctl status
        echo
    else
        text "已完成"
    fi
}

function deploy_rpcbackend_internal {
    if [[ $NODE_TYPE == 'controller' ]]; then
        head1 "部署 RpcBackend"
        MAGIC=_rpcbackend-${NODE_TYPE}
        install_rabbitmq
        local install_success=$?
        if [[ $install_success == 1 ]]; then
            config_rabbitmq
            verify_rabbitmq $?
            iniset $NODE_FILE state rpcbackend done
        fi
    fi
}

function deploy_rpcbackend {
    new_env_run "deploy_rpcbackend_internal"
}
