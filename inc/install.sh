function install_package {
    [[ $YUM_REPO == centos ]] && yum update -y
    yum install -y $@ #--skip-broken
    echo
}

function is_service_installed {
    local is_all_installed=1
    for pkg in $@; do
        if [[ $(rpm -q --quiet $pkg; echo $?) != 0 ]]; then
            is_all_installed=0
            break
        fi
    done
    return $is_all_installed
}

function install_service_package {
    local service=$1
    local name=$2
    shift 2

    head2 "安装 $name"

    local install_forced=$(is_force_enabled install)

    local is_installed=0

    is_service_installed $@
    is_installed=$?


    if [[ $install_forced == 'yes' || $is_installed != 1 ]]; then
        install_package $@

        is_service_installed $@
        is_installed=$?

        if [[ $is_installed != 1 ]]; then
            text -r "安装失败，切换为 CentOS 源"
            ((RETRY_TIMES++))
            if [[ $RETRY_TIMES == $RETRY_TIMES_MAX ]]; then
                RETRY_TIMES=0
                exit 1
            fi

            deploy_openstack_release centos
            deploy_${service}
        else
            if [[ $(get_yum_repo_type) != $YUM_REPO ]]; then
                text -g "安装成功，切换为 Fronware 源"
                deploy_openstack_release fronware
            fi
        fi
    else
        text "已安装"
    fi

    return $is_installed
}

function create_systemd_unit {
    local scontroller='ntpd mariadb rabbitmq-server memcached httpd openstack-glance-api openstack-glance-registry openstack-nova-api openstack-nova-cert openstack-nova-consoleauth openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy neutron-server openstack-cinder-api openstack-cinder-scheduler'

    local scompute='libvirtd openstack-nova-compute openvswitch openvswitch-nonetwork openstack-nova-compute neutron-openvswitch-agent'

    local snetwork='openvswitch openvswitch-nonetwork neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent'

    local scinder='openstack-cinder-volume target'
    local services=
    local node_type=$NODE_TYPE
    if [[ $SUB_NODE_TYPE == allin1 ]]; then
        node_type=allin1
        for service in $scontroller $scompute $snetwork $scinder; do
            services+="${service}.service "
        done
    else
        case $NODE_TYPE in
            controller)
                for service in $scontroller; do
                    services+="${service}.service "
                done
                ;;
            compute)
                for service in $scompute; do
                    services+="${service}.service "
                done
                ;;
            network)
                for service in $snetwork; do
                    services+="${service}.service "
                done
                ;;
            cinder)
                for service in $scinder; do
                    services+="${service}.service "
                done
                ;;
            *)
                ;;
        esac
    fi


    echo -en "[Unit]
Description=OpenStack Automatic Deployment oneshort Service
Before=$services
After=syslog.target network.target
AssertPathExists=$TOP_DIR

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c \"$TOP_DIR/stack.sh -t $node_type --restart networking\"

[Install]
WantedBy=multi-user.target"
}

function systemd_service_install {
    create_systemd_unit > /usr/lib/systemd/system/devstack.service
    systemctl enable devstack.service
}
