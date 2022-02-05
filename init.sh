#!/bin/bash

IFS=$'\n'
for repo in $(ls /etc/yum.repos.d);
do
  sed -e "s/#baseurl/baseurl/" -e "s/mirrorlist/#mirrorlist/" -e "s/mirror.*.org/vault.centos.org/" -i /etc/yum.repos.d/$repo
done

yum install -y modulemd-tools yum-utils epel-release
yum install -y python3

yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

if [ -f "/root/to_be_download_w.txt" ];then
   echo "to_be_download_w.txt file exists, will use it to download rpms and skip container building step"
   echo "rpm file name number in to_be_download_w.txt is "`cat /root/to_be_download_w.txt|wc -l`
   mkdir -p /root/kolla_wallaby

   docker run -u root -v /root/:/root/ -v /var/run/docker.sock:/var/run/docker.sock --rm -ti localhost/rpm_repo/kolla/centos-binary-base:wallaby bash -c "/root/download_rpm.sh"
   #create local rpm repo
   createrepo /root/kolla_wallaby/
   cd /root/kolla_wallaby && repo2module -s stable  . modules.yaml && modifyrepo_c --mdtype=modules modules.yaml repodata/
   exit 0
fi


#build kolla-build offline rpms cache repo

openstack_kolla_pkgs="openstack-kolla git-core less libedit openssh openssh-clients python-oslo-i18n-lang python3-GitPython python3-babel python3-debtcollector python3-docker python3-funcsigs python3-gitdb python3-importlib-metadata python3-jinja2  python3-markupsafe  python3-netaddr python3-oslo-config python3-oslo-i18n python3-pbr  python3-pytz python3-rfc3986 python3-smmap python3-stevedore python3-websocket-client python3-wrapt python3-zipp"
#install repo build tools
yum install -y modulemd-tools yum-utils

# install kolla wallaby
python3 -m pip install kolla
#yum install -y centos-release-openstack-wallaby && yum makecache
#yum install -y openstack-kolla

ls -al /usr/local
ls -al /usr/share

#fix centos 8 ceph issue
sed -e '447s!^$!RUN sed -e "s/#baseurl/baseurl/" -e "s/mirrorlist/#mirrorlist/" -e "s/mirror.*.org/vault.centos.org/" -i /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo!' -i /usr/share/kolla/docker/base/Dockerfile.j2

#fix centos 8 rpm install issue on openstack-base image
sed -i "s/'python3-sqlalchemy-collectd',//" /usr/share/kolla/docker/openstack-base/Dockerfile.j2

#build images locally and get list of rpms that need to be cached.
kolla-build --skip-existing -t binary --openstack-release wallaby --tag wallaby --registry rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove

rm -f all_rpms_w.txt w_rpm_list.txt base_rpm.txt to_be_download_w.txt

for i in `docker images |grep rpm_repo|grep -v centos-binary-base |awk '{print $3}'`;do docker run --rm -u root -v /root:/root -v /var/run/docker.sock:/var/run/docker.sock -ti $i bash -c "rpm -qa >>/root/all_rpms_w.txt";done
#add openstack kolla rpms to cache repo
for i in $openstack_kolla_pkgs;do echo $i >>/root/all_rpms_w.txt;done

cat /root/all_rpms_w.txt |sort |sort -u >/root/w_rpm_list.txt

docker run --rm -u root -v /root/:/root/ -v /var/run/docker.sock:/var/run/docker.sock -ti rpm_repo/kolla/centos-binary-base:wallaby bash -c "rpm -qa >/root/base_rpm.txt"

cat w_rpm_list.txt base_rpm.txt |sort |uniq -u >to_be_download_w.txt

mkdir -p /root/kolla_wallaby

docker run -u root -v /root/:/root/ -v /var/run/docker.sock:/var/run/docker.sock --rm -ti localhost/rpm_repo/kolla/centos-binary-base:wallaby bash -c "/root/download_rpm.sh"
#create local rpm repo
createrepo /root/kolla_wallaby/
cd /root/kolla_wallaby && repo2module -s stable  . modules.yaml && modifyrepo_c --mdtype=modules modules.yaml repodata/