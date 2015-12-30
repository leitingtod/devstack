src=/var/cache/yum/
case $# in
    0)
        user=$(cat /etc/passwd|grep 1000|cut -d ':' -f 1)
        dst=/home/$user/rpm-save
        [[ -d $dst ]] || mkdir -p $dst;;
    1)
        dst=$1
        if [[ $dst == 1 ]]; then
            dst=$(pwd)/../../../../pkg-openstack/el7
        fi;;
    2)
        src=$1
        dst=$2;;
    *)
        echo "Error: wrong arguments"
    ;;
esac

find $src -name *.rpm | xargs -i cp {} $dst
