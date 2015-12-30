function install_ntp {
    install_service_package ntp "NTP" ntp
    return $?
}

function config_ntp_controller {
    if [[ $(grep "^restrict -4 default" $1) == '' || \
                $(grep "^restrict -6 default" $1) == '' ]]; then
        sed -i '/^restrict default/{s/^/-/}' $1
        sed -i '/^-restrict default/{s/^/restrict -4 default kod notrap nomodify\nrestrict -6 default kod notrap nomodify\n/;:f;n;b f;}' $1
        sed -i '0,/^-restrict default/{/^-restrict default/d}' $1
        sed -i '/^-restrict default/{s/^-//}' $1
    fi

    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    sed -i '/^server $hostname/d' $1
    if [[ $(grep "^server $hostname" $1) == '' ]]; then
        sed -i "/^server/{s/^/server $hostname iburst\n/;:f;n;b f;}" $1
    fi
}

function config_ntp_others {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    sed -i '/^server $hostname/d' $1
    sed -i '/^server/{s/^/-/}' $1
    sed -i  "/^-server/{s/^/server $hostname iburst\n/;:f;n;b f;}" $1
    sed -i '/^-server/d' $1
    # TODO: handler duplicate line
}

function config_ntp_conf {
    local file=/etc/ntp.conf

    head2 "修改 $file"

    local conf_needed=$(is_needed_reconf $file)

    if [[ $conf_needed == 'yes' ]]; then
        if [[ $NODE_TYPE == 'controller' ]]; then
            config_ntp_controller $file
        else
            config_ntp_others $file
        fi
        text "完成"
    else
        text "已完成"
    fi
}

function config_ntp {
    # edit /etc/ntp.conf
    config_ntp_conf

    # auto start ntp
    local need_restart=$(is_needed_restart_service /etc/ntp.conf)

    start_service ntpd $need_restart
}

function verify_ntp_conf {
    grep "^server" $file
    if [[ $NODE_TYPE == 'controller' ]]; then
        grep "^restrict" $file
        echo
    fi
}

function verify_ntp {
    head2 "检查修改后的配置文件"

    local file=/etc/ntp.conf
    verify_conf_file $file verify_ntp_conf

    head2 "检查 NTP服务是否正常"

    local need_verify=$(is_needed_verify_service $file)

    if [[ $need_verify == 'yes' ]]; then
        text "ntpq -c peers"
        ntpq -c peers
        echo

        text -n "ntpq -c assoc"
        ntpq -c assoc
        echo
        text "完成"
    else
        text "已完成"
    fi
}

function deploy_ntp {
    head1 "部署 NTP"
    MAGIC=_ntp-${NODE_TYPE}
    install_ntp
    local install_success=$?
    if [[ $install_success == 1 ]]; then
        config_ntp
        verify_ntp
        iniset $NODE_FILE state ntp done
    fi
}
