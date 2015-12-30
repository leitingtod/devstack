[[ -d $1 ]] || mkdir -p $1
cp /etc/hostname /etc/hosts /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/ntp.conf /etc/my.cnf.d/mariadb_openstack.cnf /etc/keystone/keystone.conf /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/wsgi-keystone.conf /usr/share/keystone/keystone-dist-paste.ini $1
