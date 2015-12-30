function sudo_no_password {
    user=$(id -n -u)
    file=/etc/sudoers
    head2 "配置免密码使用 sudo"
    if [[ $user != 'root' && $( grep "$user ALL=(ALL)" $file) == '' ]]; then
        sed -i "\$a $user ALL=(ALL) NOPASSWD:ALL"
        text "完成"
    else
        text "已完成"
    fi
}

function config_security_policy {
    head1 "配置安全服务"
    # head2 "设置 root 用户密码"
    # if [[ $( passwd root -S|cut -d ' ' -f 2) == 'LK' ]]; then
    #      passwd root
    # else
    #     text "已完成"
    # fi

    # sudo_no_password

    head2 "关闭 SELinux"
    if [[ $(getenforce) == 'Enforcing' ]]; then
        setenforce 0
        local file=/etc/selinux/config
        [[ $(is_file_exist $file) == 'yes' ]] ||  cp -a $file ${file}${MAGIC}_bak
        sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  $file
        text "完成"
    else
        text "已完成"
    fi

    head2 "关闭 Firewalld"
    local exist=$(systemctl list-unit-files|grep firewalld.service)
    if [[ $exist != '' && $(systemctl is-enabled firewalld) == 'enabled' ]]; then
        systemctl disable firewalld
        systemctl stop firewalld
        text "完成"
    else
        text "已完成"
    fi
}

function get_unused_disk {
    # exactly this function get all disk except the 1st dist
    local disks=`lsblk|grep disk|cut -d ' ' -f 1`
    local devs=
    for dev in $disks; do
        local partion_cnt=`lsblk | grep $dev | wc -l`
        if [[ $partion_cnt > 1 ]]; then
            continue
        else
            devs+="$dev "
        fi
    done
    echo $devs
}

function get_all_disk {
    echo `lsblk -P |grep disk|cut -d '"' -f 2`
}

function get_ifdev {
    #echo `ifstat |cut -d ' ' -f 1|grep '^e'`
    echo `ip addr | grep ^2: |awk -F ":" '{print$2}'`
}

function get_nth_ifdev {
    local pos=$1
    ((pos++))
    echo `ip addr | grep ^${pos}: |awk -F ":" '{print$2}'`
}

function get_firstip {
    local dev=$(get_ifdev)
    echo `ip addr show $dev  | grep "global dynamic" | awk -F " " '{print$2}'`
}

function get_secondip {
    local dev=$(get_ifdev)
    echo `ip addr show $dev  | grep "global secondary" | awk -F " " '{print$2}'`
}

function is_partion_exist {
    local dev=$1
    local partion_cnt=`fdisk -l|grep $dev|wc -l`
    if [[ $partion_cnt > 1 ]]; then
        echo yes
    else
        echo no
    fi
}

function is_pv_exist {
    local pvname=$1
    local pvlist=`pvs | grep $pvname | cut -d ' ' -f 3`
    echo $(is_str_in_list $pvname $pvlist)
}

function is_pv_in_vg {
    local pv=$1
    local vg=$2
    local pvget=`pvs | grep $pv | cut -d ' ' -f 3`
    local pvs=`pvs | grep $vg | cut -d ' ' -f 3`

    echo $(is_str_in_list $pvget $pvs)
}

function is_vgroup_exist {
    local vgname=$1
    local vglist=`vgs | grep $vgname | cut -d ' ' -f 3`
    echo $(is_str_in_list $vgname $vglist)
}

function is_str_in_list {
    local str=$1
    shift 1
    for elem in $@; do
        if [[ ${str}x == ${elem}x ]]; then
            echo 'yes'
            return
        fi
    done
    echo 'no'
}

function is_service_exist {
    local service=$1
    local service_name=`openstack service list | grep $service |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

    echo $(is_str_in_list $service $service_name)
    # service_name may be 'cinder cinderv2'
}

function is_endpoint_exist {
    local service_type=$1
    local endpoint=`openstack endpoint list | grep $service_type | awk -F "|" '{print$5}' | awk -F " " '{print$1}'`

    # endpoint may be 'cinder cinderv2'
    echo $(is_str_in_list $service_type $endpoint)
}

function is_project_exist {
    local name=$1
    local prj=`openstack project list | grep $name | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

    echo $(is_str_in_list $name $prj)
}

function is_user_exist {
    local name=$1
    local user=`openstack user list | grep $name | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
    echo $(is_str_in_list $name $user)
}

function is_role_exist {
    local name=$1
    local role=`openstack role list | grep $name | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
    echo $(is_str_in_list $name $role)
}

function is_openstack_role_added {
    local prj=$1
    local user=$2
    local role=$3

    local rolename=`openstack user role list --project $prj $user | grep $user | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

    echo $(is_str_in_list $role $rolename)
}

function is_image_exist {
    local image=$1
    local imageid=`glance image-list | grep $image | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

    echo $(is_str_in_list $image $imageid)
}

function is_cinder_volume_exist {
    local volume=$1
    local volumeid=`cinder list | grep $volume | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`

    echo $(is_str_in_list $volume $volumeid)
}

function create_project {
    local prj=$1
    local desc=$2
    head3 "创建 Project $prj"
    if [[ $(is_project_exist $prj) == 'yes' ]]; then
        text "已创建"
    else
        local cmd="openstack project create --description \"$desc\" $prj"
        text -n "$cmd"
        openstack project create --description "$desc" $prj
        echo
    fi
}

function create_user_role {
    local user=$1
    local pass=$2
    local role=$3
    local cmd=
    create_user $user $pass
    create_role $role
}

function create_user {
    local user=$1
    local pass=$2
    local cmd=
    head3 "创建 User $user"
    if [[ $(is_user_exist $user) == 'yes' ]]; then
        text "已创建"
    else
        cmd="openstack user create --password $pass $user"
        text -n "$cmd"
        openstack user create --password $pass $user
        echo
    fi
}

function create_role {
    local role=$1
    local cmd=
    head3 "创建 Role $role"
    if [[ $(is_role_exist $role) == 'yes' ]]; then
        text "已创建"
    else
        cmd="openstack role create $role"
        text -n "$cmd"
        openstack role create $role
        echo
    fi
}

function openstack_role_add {
    local prj=$1
    local user=$2
    local role=$3
    head3 "设置 Project $prj 的用户 $user 的角色为 $role"
    if [[ $(is_openstack_role_added $prj $user $role) == 'yes' ]]; then
        text "已完成"
    else
        local cmd="openstack role add --project $prj --user $user $role"
        text -n "$cmd"
        openstack role add --project $prj --user $user $role
        echo
    fi
}

function create_service {
    local service_name=$1
    local service_desc=$2
    local service_type=$3

    head3 "创建 $service_name Service"
    if [[ $(is_service_exist $service_name) == 'yes' ]]; then
        text "已创建"
    else
        local cmd="openstack service create --name $service_name --description \"$service_desc\" $service_type"
        text -n "$cmd"
        openstack service create --name $service_name --description "$service_desc" $service_type
        echo
    fi
}

function create_endpoint {
    local service_name=$1
    local region=$2
    local service_type=$3
    shift 3
    head3 "创建 $service_name Endpoint"
    if [[ $(is_endpoint_exist $service_type) == 'yes' ]]; then
        text "已创建"

    else
        local cmd="openstack endpoint create $@ --region $region $service_type"
        text -n "$cmd"
        openstack endpoint create $@ --region $region $service_type
        echo
    fi
}

function config_keystone_openrc {
    local hostname=$(iniget $CONF_FILE $NODE_TYPE HOSTNAME)
    export OS_TOKEN=$(iniget $CONF_FILE $NODE_TYPE ADMIN_TOKEN)
    export OS_URL=http://$hostname:35357/v2.0
}

function config_openrc {
    local hostname=$(iniget $CONF_FILE controller HOSTNAME)
    local prj=$1
    local pass=$2
    local url="http://${hostname}:35357/v3"

    echo "unset OS_TOKEN OS_URL"
    echo "export OS_PROJECT_DOMAIN_ID=default"
    echo "export OS_USER_DOMAIN_ID=default"
    echo "export OS_PROJECT_NAME=$prj"
    echo "export OS_TENANT_NAME=$prj"
    echo "export OS_USERNAME=$prj"
    echo "export OS_PASSWORD=$pass"
    echo "export OS_AUTH_URL=$url"
    echo "export OS_IMAGE_API_VERSION=2"
    echo "export OS_VOLUME_API_VERSION=2"
}

function update_openrc_files {
    #local user=$(cat /etc/passwd|grep 1000|cut -d ':' -f 1)

    local pass=$(iniget $CONF_FILE controller ADMIN_PASS)
    local file=$TOP_DIR/files/admin-openrc.sh
    [[ $DEBUG_ALLIN1 == yes ]] && file=$LOG_DIR/admin-openrc.sh
    config_openrc admin $pass > $file

    pass=$(iniget $CONF_FILE controller DEMO_PASS)
    file=$TOP_DIR/files/demo-openrc.sh
    [[ $DEBUG_ALLIN1 == yes ]] && file=$LOG_DIR/demo-openrc.sh
    config_openrc demo $pass > $file
}

function source_admin_openrc {
    if [[ $DEBUG_ALLIN1 == yes ]]; then
        source $LOG_DIR/admin-openrc.sh
    else
        source $TOP_DIR/files/admin-openrc.sh
    fi
}

function source_demo_openrc {
    if [[ $DEBUG_ALLIN1 == yes ]]; then
        source $LOG_DIR/demo-openrc.sh
    else
        source $TOP_DIR/files/demo-openrc.sh
    fi
}

function config_lvm_conf {
    local file=/etc/lvm/lvm.conf

    if [[ $(is_file_exist $file) == 'yes' ]]; then
        sed -i "/^devices/,/^}/{/filter/d}" $file

        local filter="filter = [ "
        for disk in $(get_all_disk); do
            filter+="\"a/$disk/\", "
        done

        filter+="\"r/.*/\" ]"
        sed -i "/^devices/,/^}/s|^}|    $filter\n}|" $file
    fi
}

function fdisk_to_lvm {
    local disk=$1
    fdisk $disk <<EOF
n
p
1


t
8e
w
EOF
}
