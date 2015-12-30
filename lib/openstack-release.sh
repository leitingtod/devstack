function install_official_openstack {
    if [[ $(is_host_reachable www.baidu.com) == no ]]; then
        ((RETRY_TIMES++))
        if [[ $RETRY_TIMES == $RETRY_TIMES_MAX ]]; then
            RETRY_TIMES=0
            exit 1
        fi
        deploy_networking
    fi

    install_service_package openstack_release "EPEL-7, RDO-RELEASE" epel-release centos-release-openstack-kilo
    return $?
}

function switch_yum_repos {
    local tmp=/tmp/repos
    local repo=/etc/yum.repos.d
    local fronware=openstack-kilo-fw.repo
    local centos=CentOS-OpenStack-kilo.repo

    [[ -d /tmp/repos ]] || mkdir /tmp/repos
    case $1 in
        centos)
            [[ -e $tmp/$centos ]] && mv -f $tmp/$centos $repo/$centos
            [[ -e $repo/$fronware ]] && rm -f $repo/$fronware
        ;;
        fronware)
            [[ -e $repo/$centos ]] && mv -f $repo/$centos $tmp/$centos
            cp -u $TOP_DIR/files/$fronware $repo/$fronware
        ;;
    esac
    yum clean all -q 2>/dev/null
}

function get_yum_repo_type {
    local file=/etc/yum.repos.d/openstack-kilo-fw.repo
    if [[ $(is_file_exist $file) == yes ]]; then
        echo fronware
    else
        echo centos
    fi
}

function config_openstack_release {
    head2 "配置 OpenStack Kilo 软件源"
    switch_yum_repos $1
    text "完成"
}

function verify_openstack_release {
    if [[ $(get_yum_repo_type) == fronware ]]; then
        local file=/etc/yum.repos.d/openstack-kilo-fw.repo
        head2 "检查修改后的配置文件"
        verify_conf_file $file
        make_sha1_file $file
    fi
}

function deploy_openstack_release {
    local install_success=
    head1 "部署 OpenStack Packages " "[" -g -B ${1^^} -B -y "]"
    if [[ $1 != fronware ]]; then
        install_official_openstack
        install_success=$?
    else
        install_success=1
    fi

    if [[ $install_success == 1 ]]; then
        config_openstack_release $1
        verify_openstack_release
        iniset $NODE_FILE state openstack-release done
    fi
}

function upgrade_then_reboot {
    if [[ $(iniget $NODE_FILE state openstack-release) != 'done' ]]; then
        #cp $TOP_DIR/files/stack.service /etc/systemd/system/multi-user.target.wants/stack.service
        #systemctl enable stack.service

        iniset $NODE_FILE state openstack-release done

        # local timeout=7
        # cecho -r "将在" -B -y "$timeout" -B -r "秒后重启电脑!!" -b "如需取消，请按" -B -y "Ctrl-C。" -b "开机后请重新运行" -B -y "stack.sh" -B "!!" -n
        # sleep $timeout
        # reboot
    else
        systemctl disable stack.service
    fi
}
