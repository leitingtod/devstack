function make_sha1_file {
    local file=$1
    local tmp=/tmp/devstack
    [[ -d $tmp ]] || mkdir -p $tmp
    [[ $file != '' ]] && sha1sum $file > $tmp/$(basename $file)${MAGIC}.sig
}

function is_local_conf_changed {
    echo $(is_file_changed $CONF_FILE)
}

function is_file_exist {
    local file=$1
    if [[ -d $(dirname $file) ]]; then
        local is_exist=$(ls $(dirname $file)|grep "$(basename $file)\$")
        if [[ $is_exist != "" ]]; then
            echo yes
        else
            echo no
        fi
    else
        echo no
    fi
}

function is_file_changed {
    if [[ $# < 1 ]]; then
        echo no
        return
    fi
    local file=$1
    if [[ $file == '' ]]; then
        echo 'no'
        return
    fi

    local sha1=/tmp/devstack/$(basename $file)${MAGIC}.sig

    if [[ $(is_file_exist $sha1) == 'yes' ]]; then
        old=$(cat $sha1 | cut -d ' ' -f 1)
        local new=$(sha1sum $file|cut -d ' ' -f 1)

        if [[ $old != $new ]]; then
            echo 'yes'
        else
            echo 'no'
        fi
    else
        echo 'new'
    fi
}

function is_files_changed {
    local ret=0
    for file in $@; do
        if [[ $(is_file_exist $file) == 'yes' ]]; then
            if [[ $(is_file_changed $file) == 'yes' ||
                        $(is_file_changed $file) == 'new' ]]; then
                ret=yes
                break
            fi
        fi
    done
    echo $ret
}

function is_force_enabled {
    if [[ $REINSTALL == 'yes' && $1 == 'install' ]]; then
        echo yes
    elif [[ $RECONF == 'yes' && $1 == 'config' ]]; then
        echo yes
    elif [[ $VERIFY == 'yes' && $1 == 'verify' ]]; then
        echo yes
    else
        echo no
    fi
}

function is_needed_restart_service {
    # 文件被改后，会重新配置为默认的，此时肯定是未改变的 TODO
    local conf_modified=$(is_files_changed $@)

    local conf_forced=$(is_force_enabled config)

    # is_force_enabled verify 强制验证，但有可能配置文件未变化，因此无需判断

    if [[ $conf_modified == 'yes' || $conf_forced == 'yes' ]]; then
        echo hard
    elif [[ $(is_force_enabled verify) == 'yes' ]]; then
        echo soft
    else
        echo no
    fi
}

function is_needed_verify {
    local file=$1

    local conf_changed=$(is_file_changed $file)

    local conf_forced=$(is_force_enabled config)

    local verify_forced=$(is_force_enabled verify)

    if [[ $conf_changed == 'yes' || $conf_changed == 'new' ||
                $conf_forced == 'yes' ||
                $verify_forced == 'yes' ]]; then
        echo yes
    else
        echo no
    fi
}

function is_needed_verify_service {
    local ret=
    if [[ $# > 0 ]]; then
        for file in $@; do
            if [[ $(is_needed_verify $file) == 'yes' ]]; then
                ret+='yes '
                make_sha1_file $file
            else
                ret+='no '
            fi
        done
    else
        ret=$(is_needed_verify)
    fi

    [[ $(is_local_conf_changed) == yes ||
             $(is_local_conf_changed) == new ]] && make_sha1_file $CONF_FILE

    if [[ $(is_str_in_list 'yes' $ret) == 'yes' ]]; then
        echo yes
    else
        echo no
    fi
}

function verify_conf_file {
    local file=$1
    local func=$2

    local needed_verify=$(is_needed_verify $file)

    head3 "检查 $file"

    if [[ $needed_verify == 'yes' ]]; then
        if [[ $func != '' ]]; then
            $func
        else
            grep -v "#" $file|grep "[^$]"|highlight --src-lang=ini -O ansi
            echo
        fi
    else
        text  "文件无变化"
    fi
}

function is_host_reachable {
    local target=$1
    local count=$(ping -c 2 $target | grep icmp* | wc -l )

    if [ $count -eq 0 ]; then
        echo no
    else
        echo yes
    fi
}

function is_empty_dir {
    if [[ $(ls $1 | wc -l) == 0 ]]; then
        echo yes
    else
        echo no
    fi
}
