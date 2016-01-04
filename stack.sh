#!/usr/bin/env bash
function auto_mode {
    if [[ $SUB_NODE_TYPE == 'allin1' ]]; then
        single_node_mode
    else
        multi_node_mode
    fi
}

function multi_node_mode {
    deploy_networking
    deploy_openstack_release $YUM_REPO
    deploy_ntp
    deploy_database
    deploy_rpcbackend
    deploy_keystone
    deploy_glance
    deploy_nova
    deploy_neutron
    deploy_cinder
    deploy_horizon
}

function single_node_mode {
    #controller
    NODE_TYPE=controller
    deploy_networking
    deploy_openstack_release $YUM_REPO
    deploy_ntp
    deploy_database
    deploy_rpcbackend
    deploy_keystone
    deploy_glance

    #compute
    NODE_TYPE=controller
    deploy_nova

    NODE_TYPE=compute
    deploy_nova

    #neutron
    NODE_TYPE=controller
    deploy_neutron

    NODE_TYPE=network
    deploy_neutron

    NODE_TYPE=compute
    deploy_neutron

    #cinder
    NODE_TYPE=controller
    deploy_cinder

    NODE_TYPE=cinder
    deploy_cinder

    NODE_TYPE=controller
    deploy_horizon
}

function update_environment_internal {
    echo "export CONF_FILE=$CONF_FILE"
    echo "export NODE_FILE=$NODE_FILE"

    echo "export NODE_TYPE=$NODE_TYPE"
    echo "export SUB_NODE_TYPE=$SUB_NODE_TYPE"
    echo "export YUM_REPO=$YUM_REPO"
    echo "export RECONF=$RECONF"
    echo "export VERIFY=$VERIFY"

    echo "export DEBUG=$DEBUG"
    echo "export DEBUG_ALLIN1=$DEBUG_ALLIN1"
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    echo "export HOSTNAME=$hostname"
    echo "export TOP_DIR=$TOP_DIR"

    echo -en 'for file in $(ls $TOP_DIR/inc/* $TOP_DIR/lib/*); do
        source $file
    done'
}

function new_env_run {
    update_environment_internal > $TOP_DIR/files/parent-env.sh
    bash -c "source $TOP_DIR/files/parent-env.sh; $1"
}

function test_environment {
    echo
    echo "VERSION = $VERSION"
    echo "CONF_FILE = $CONF_FILE"
    echo "NODE_FILE = $NODE_FILE"
    echo "NODE_TYPE_LIST = $NODE_TYPE_LIST"

    echo "NODE_TYPE = $NODE_TYPE"
    echo "SUB_NODE_TYPE = $SUB_NODE_TYPE"
    echo "AUTO_MODE = $AUTO_MODE"
    echo "YUM_REPO = $YUM_REPO"
    echo "RECONF = $RECONF"
    echo "VERIFY = $VERIFY"
    echo "RESTART = $RESTART"
    echo "RESTART_SERVICE = $RESTART_SERVICE"

    echo "DEBUG = $DEBUG"
    echo "DEBUG_OPT = $DEBUG_OPT"
    echo "DEBUG_ALLIN1 = $DEBUG_ALLIN1"

    echo "NOCOLOR = $CECHO_IS_INACTIVE"
    echo
}

function exit_clean {
    unset NODE_FILE
    unset CONF_FILE
    unset NODE_TYPE_LIST

    unset RETRY_TIMES_MAX
    unset RETRY_TIMES

    unset NODE_TYPE
    unset SUB_NODE_TYPE
    unset AUTO_MODE
    unset RECONF
    unset VERIFY

    unset DEBUG
    unset DEBUG_OPT
    unset NOCOLOR

    unset YUM_REPO
    unset MAGIC
    unset VERSION
}

function usage {
    cecho -y "\n用法：" -b "sudo ./stack.sh -t|--type 结点类型 command\n"
    cecho -b "必选参数：" -g "\e-t" -b -B "|" -B  -g "--type" -b " 结点类型"
    cecho -b -iv "必选参数：" -d -b "指定结点类型，""结点类型：" -g "controller" -b -B "|" -B  -g "compute" -b -B "|" -B -g  "network" -b -B "|" -B -g  "cinder"  -b -B "|" -B -g "allin1" -n

    cecho -b "可选参数：" -d -g  "-h | --help" -b " 帮助"
    cecho -b "可选参数：" -d -g  "-r | --restart" -b " 服务"
    cecho -b -iv "可选参数：" -d -b "重启指定服务，""结点类型：" -g "glance" -b -B "|" -B  -g "nova" -b -B "|" -B -g  "neutron" -b -B "|" -B -g  "cinder"  -b -B "|" -B -g  "horizon" -n
    cecho -b "可选命令：" -g "auto" -t -t -b "不进入交互模式"
    cecho -b -iv "可选命令：" -d -g  "reconf" -t -b "重新配置"
    cecho -b -iv "可选命令：" -d -g  "verify " -t -b "仅验证，不修改已有配置\n"
    exit 1
}

function select_mode {
    prompt hed "请选择您希望的" "工作" "模式：\n"
    select mode in 手动 自动; do
        prompt sel "\n进入" $mode "工作模式\n"
        case $mode in
            手动 )
                manual_mode
                break;;
            自动)
                auto_mode
                break;;
            *)
                prompt err "\n无此模式，请选择正确的模式" "序号" "！\n";;
        esac
    done
}

function manual_mode {
    local service_list=
    prompt hed "请选择您希望自动配置的" "服务：\n"

    if [[ $NODE_TYPE == 'controller' ]]; then
        service_list='Networking OpenStack-Package NTP MySql RabbitMq Keystone Glance Nova Neutron Cinder Horizon'
    elif [[ $NODE_TYPE == 'compute' ]]; then
        service_list='Networking OpenStack-Package NTP Nova Neutron'
        config_lvm_conf
    elif [[ $NODE_TYPE == 'network' ]]; then
        service_list='Networking OpenStack-Package NTP Neutron'
        config_lvm_conf
    elif [[ $NODE_TYPE == 'cinder' ]]; then
        service_list='Networking OpenStack-Package NTP Cinder'
    fi

    select service in $service_list; do
        case $service in
            Networking)
                prompt sel "\n开始配置" $service "服务\n"
                deploy_networking
                break;;
            OpenStack-Package)
                if [[ $(iniget $NODE_FILE state networking) != 'done' ]]; then
                    prompt err "\n请先配置" "Networking" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_openstack_release $YUM_REPO
                break;;
            NTP)
                if [[ $(iniget $NODE_FILE state openstack-release) != 'done' ]]; then
                    prompt err "\n请先配置" "OpenStack-Package" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_ntp
                break;;
            MySql)
                if [[ $(iniget $NODE_FILE state ntp) != 'done' ]]; then
                    prompt err "\n请先配置" "NTP" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_database
                break;;
            RabbitMq)
                if [[ $(iniget $NODE_FILE state database) != 'done' ]]; then
                    prompt err "\n请先配置" "MySql" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_rpcbackend
                break;;
            Keystone)
                if [[ $(iniget $NODE_FILE state rpcbackend) != 'done' ]]; then
                    prompt err "\n请先配置" "RabbitMq" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_keystone
                break;;
            Glance )
                if [[ $(iniget $NODE_FILE state keystone) != 'done' ]]; then
                    prompt err "\n请先配置" "Keystone" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                deploy_glance
                break;;
            Nova )
                if [[ $(iniget $NODE_FILE state glance) != 'done' &&
                            $NODE_TYPE == controller ]]; then
                    prompt err "\n请先配置" "Glance" "！\n"
                    break
                fi

                if [[ $(iniget $NODE_FILE state ntp) != 'done' &&
                            $NODE_TYPE == compute ]]; then
                    prompt err "\n请先配置" "NTP" "！\n"
                    break
                fi

                prompt sel "\n开始配置" $service "服务\n"
                if [[ $SUB_NODE_TYPE == allin1 ]]; then
                    NODE_TYPE=controller
                    deploy_nova
                    NODE_TYPE=compute
                    deploy_nova
                else
                    deploy_nova
                fi
                break;;
            Neutron )
                if [[ $NODE_TYPE == network &&
                            $(iniget $NODE_FILE state ntp) != 'done' ]]; then
                    prompt err "\n请先配置" "NTP" "！\n"
                    break
                fi

                if [[ $NODE_TYPE == controller || $NODE_TYPE == compute ]]; then
                    if [[ $(iniget $NODE_FILE state nova) != 'done' ]]; then
                        prompt err "\n请先配置" "Nova" "！\n"
                        break
                    fi
                fi
                prompt sel "\n开始配置" $service "服务\n"
                if [[ $SUB_NODE_TYPE == allin1 ]]; then
                    NODE_TYPE=controller
                    deploy_neutron
                    NODE_TYPE=network
                    deploy_neutron
                    NODE_TYPE=compute
                    deploy_neutron
                else
                    deploy_neutron
                fi
                break;;
            Cinder )
                if [[ $(iniget $NODE_FILE state ntp) != 'done' ]]; then
                    prompt err "\n请先配置" "NTP" "！\n"
                    break
                fi
                prompt sel "\n开始配置" $service "服务\n"
                if [[ $SUB_NODE_TYPE == allin1 ]]; then
                    NODE_TYPE=cinder
                    deploy_cinder
                    NODE_TYPE=controller
                    deploy_cinder
                else
                    deploy_cinder
                fi
                break;;
            Horizon)
                prompt sel "\n开始配置" $service "服务\n"
                deploy_horizon
                break;;
            * )
                prompt err "\n无此服务，请选择正确的服务" "序号" "！\n";;
        esac
    done
}

function restart_service {
    case $RESTART in
        networking)
            deploy_networking
            exit 1;;
        glance)
            start_glance $restart_type
            exit 1;;
        nova)
            if [[ $SUB_NODE_TYPE == allin1 ]]; then
                start_nova_controller $restart_type
                start_nova_compute $restart_type
            else
                if [[ $(is_str_in_list $NODE_TYPE 'controller compute') == yes ]]; then
                    start_nova_${NODE_TYPE} $restart_type
                fi
            fi
            exit 1;;
        neutron)
            if [[ $SUB_NODE_TYPE == allin1 ]]; then
                start_neutron_controller $restart_type
                start_neutron_network $restart_type
                start_neutron_compute $restart_type
            else
                if [[ $(is_str_in_list $NODE_TYPE 'controller compute network') == yes ]]; then
                    start_neutron_${NODE_TYPE} $restart_type
                fi
            fi
            exit 1;;
        cinder)
            if [[ $SUB_NODE_TYPE == allin1 ]]; then
                start_cinder_controller $restart_type
                start_cinder_blockstorage $restart_type
            else
                if [[ $NODE_TYPE == controller ]]; then
                    start_cinder_controller $restart_type
                elif [[]]; then
                     start_cinder_blockstorage $restart_type
                fi
            fi
            exit 1;;
        horizon)
            start_service memcached $restart_type
            start_service httpd $restart_type
            exit 1;;
        *)
            exit 1;;
    esac
}

function include_source {
    for file in $(ls $TOP_DIR/inc/* $TOP_DIR/lib/*); do
        source $file
    done
}

function main {
    TOP_DIR=$(cd $(dirname "$0") && pwd)
    LOG_DIR=/var/log/devstack

    NODE_FILE=$TOP_DIR/node.conf
    CONF_FILE=$TOP_DIR/local.conf
    NODE_TYPE_LIST='controller compute network cinder'

    RETRY_TIMES_MAX=3
    RETRY_TIMES=0

    NODE_TYPE=
    AUTO_MODE=
    RECONF=
    VERIFY=

    DEBUG=
    DEBUG_OPT=
    NOCOLOR=

    YUM_REPO=fronware
    MAGIC=

    include_source

    local index=1

    local opt_value_list='controller compute network cinder allin1 centos networking ntp mysql rabbitmq keystone glance nova neutron horizon'

    for opt in $@; do
        #echo "opt: $opt, pos: $index"
        ((index++))
        case $opt in
            --type|-t)
                NODE_TYPE=${!index}
                if [[ $(is_str_in_list $NODE_TYPE $opt_value_list) == 'no' ]]; then
                    prompt err "\n错误的结点类型" "$NODE_TYPE" "！"
                    usage
                fi
                ;;
            --yum|-y)
                YUM_REPO=${!index}
                if [[ $(is_str_in_list $YUM_REPO $opt_value_list) == 'no' ]]; then
                    prompt err "\n错误的服务类型" "$RESTART" "！"
                    usage
                fi;;
            --help|-h)
                usage;;
            --version|-v)
                cecho -n -b "DevStack " -y "$VERSION" -n
                exit 1;;
            auto)
                AUTO_MODE=yes;;
            reconf)
                RECONF=yes;;
            verify)
                VERIFY=yes;;
            --restart|-r)
                RESTART=${!index}
                if [[ $(is_str_in_list $RESTART $opt_value_list) == 'no' ]]; then
                    prompt err "\n错误的服务类型" "$RESTART" "！"
                    usage
                fi;;
            debug)
                DEBUG=yes;;
            debug-opt)
                DEBUG=yes
                DEBUG_OPT=yes;;
            debug-allin1)
                DEBUG=yes
                DEBUG_ALLIN1=yes;;

            nocolor)
                CECHO_IS_INACTIVE=1;;
            *)
                if [[ $(is_str_in_list $opt $opt_value_list) == 'no' ]]; then
                    prompt err "\n错误的参数" "$opt" "！"
                    usage
                else
                    continue
                fi;;
        esac
    done

    if  [[ $(whoami) != 'root' ]]; then
        cecho -r -n "请使用" -y -B "root" -B -r "用户执行。" -n
        exit 1
    fi

    if [[ $(yum list installed|grep highlight) == '' ]]; then
        rpm -i $TOP_DIR/files/highlight-3.13-3.el7.x86_64.rpm > /dev/null
    fi

    [[ $DEBUG == 'yes' ]] && test_environment|highlight --src-lang=ini -O ansi

    [[ -e $LOG_DIR ]] || mkdir -p $LOG_DIR

    [[ $DEBUG == 'yes' ]] && NODE_FILE=$LOG_DIR/node.conf

    [[ $DEBUG_ALLIN1 == 'yes' ]] && CONF_FILE=$LOG_DIR/local.conf

    [[ $DEBUG_ALLIN1 == 'yes' && ! -e $CONF_FILE ]] && cp $TOP_DIR/local.conf $CONF_FILE

    if [[ $NODE_TYPE == 'allin1' ]]; then
        NODE_TYPE=controller
        SUB_NODE_TYPE=allin1
        NODE_TYPE_LIST='controller'
    fi

    if [[ $DEBUG_OPT == yes ]]; then
        systemd_service_install
        exit 1
        update_environment > $TOP_DIR/files/parent-env.sh
    fi

    [[ $RESTART != '' ]] && restart_service

    config_security_policy

    update_openrc_files
    systemd_service_install

    if [[ $AUTO_MODE == yes ]]; then
        auto_mode
    else
        select_mode
    fi
    exit_clean
    exit 1
}

NOUNSET=${NOUNSET:-}
if [[ -n "$NOUNSET" ]]; then
    set -o nounset
fi

VERSION=1.1.9
main $@
