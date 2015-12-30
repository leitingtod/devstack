function config_ifcfg {
    local ip=$(iniget $CONF_FILE $NODE_TYPE IP)
    local prefix=$(iniget $CONF_FILE $NODE_TYPE PREFIX)
    head2 "添加 IP -> $ip"

    if [[ $(get_firstip|cut -d '/' -f 1) == $ip ]]; then
        text "无需更改"
        return
    fi

    local dev=$(get_ifdev)
    local file=/etc/sysconfig/network-scripts/ifcfg-${dev}
    local is_dhcp=$([[ $(grep dhcp $file) != '' ]] && echo yes || echo no)
    local str1=IPADDR
    local str2=PREFIX

    if [[ $is_dhcp == yes ]]; then
        str1=IPADDR1
        str2=PREFIX1
    fi

    local reconf_needed=$(is_needed_reconf $file)

    if [[ $(grep "$str1" $file) == '' || $reconf_needed == 'yes' ]]; then
        sed -i "/$str1/d" $file
        sed -i "/$str2/d" $file
        sed -i "\$a $str1=$ip\n$str2=$prefix" $file
        text "完成"
    else
        text "已完成"
    fi

    if [[ $(get_secondip) == '' ]]; then
        ip addr add $ip/$prefix dev $dev
        ip link set $dev up
    fi
}

function config_hostname {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    local file=/etc/hostname
    head2 "设置 hostname -> $hostname"

    if [[ $(hostname) != $hostname ]]; then
        local reconf_needed=$(is_needed_reconf $file)
        if [[ $reconf_needed == 'yes' ]]; then
            hostnamectl --static set-hostname $hostname
            hostnamectl --transient set-hostname $hostname
            hostnamectl --pretty set-hostname $hostname
            text "完成"
        else
            text "已完成"
        fi
    else
        text "无需更改"
    fi
}

function config_hosts {
    head2 "配置 hosts"
    local file=/etc/hosts
    local reconf_needed=$(is_needed_reconf $file)

    if [[ $reconf_needed == 'yes' ]]; then
        for node in $NODE_TYPE_LIST; do
            hostname=$(iniget $CONF_FILE $node HOSTNAME)
            ip=$(iniget $CONF_FILE $node IP)
            sed -i "/$hostname/d" $file
            sed -i "/$ip/d" $file
        done

        for node in $NODE_TYPE_LIST; do
            local ip=$(iniget $CONF_FILE $node IP)
            hostname=$(iniget $CONF_FILE $node HOSTNAME)
            sed -i "\$a $ip $hostname" $file
            #[[ $node == controller ]] && echo "127.0.0.1 $hostname" >> /etc/hosts
        done
        text "完成"
    else
        text "已完成"
    fi
}

function config_networking {
    # set ip
    config_ifcfg

    # set hostname
    config_hostname

    # edit hosts
    config_hosts

    # restart network
    head2 "重启网络服务"

    local file=/etc/sysconfig/network-scripts/ifcfg-$(get_ifdev)
    local file1=/etc/hostname
    local file2=/etc/hosts

    local need_restart=$(is_needed_restart_service $file $file1 $file2)

    if [[ $need_restart == 'hard' ]]; then
        service network restart
        text "完成"
    else
        text "已完成"
    fi
}

function verify_networking {
    head2 "检查修改后的配置文件"
    local file=/etc/sysconfig/network-scripts/ifcfg-$(get_ifdev)
    local file1=/etc/hostname
    local file2=/etc/hosts

    verify_conf_file $file
    verify_conf_file $file1
    verify_conf_file $file2

    head2 "检查网络是否连通"

    local need_verify=$(is_needed_verify_service $file $file1 $file2)

    if [[ $need_verify == 'yes' ]]; then
        text "检查网络接口 ip addr"
        ip addr
        echo
        local opt='-c 2'
        for node in $NODE_TYPE_LIST; do
            if [[ $node != $NODE_TYPE ]]; then
                local ip=$(iniget $CONF_FILE $node IP)
                local hostname=$(iniget $CONF_FILE $node HOSTNAME)
                text "检查内网 $hostname"
                ping $opt $hostname
                echo
            fi
        done

        # ping external network
        local url='www.baidu.com'
        text "检查外网 $url"
        ping $opt $url
        echo
        text "完成"
    else
        text "已完成"
    fi
}

function deploy_networking {
    head1 "配置 Networking"
    MAGIC=_networking-${NODE_TYPE}
    config_networking
    verify_networking
    iniset $NODE_FILE state networking done
}
