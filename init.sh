#!/bin/bash

#this script should be run on build server with internet access, and run before build_base_wallaby.sh
#build kolla-build offline rpms cache repo
echo "starting...."
openstack_kolla_pkgs="openstack-kolla git-core less libedit openssh openssh-clients python-oslo-i18n-lang python3-GitPython python3-babel python3-debtcollector python3-docker python3-funcsigs python3-gitdb python3-importlib-metadata python3-jinja2  python3-markupsafe  python3-netaddr python3-oslo-config python3-oslo-i18n python3-pbr  python3-pytz python3-rfc3986 python3-smmap python3-stevedore python3-websocket-client python3-wrapt python3-zipp"
#install repo build tools
yum install -y modulemd-tools yum-utils epel-release

# install kolla wallaby
rm -rf /tmp/all_rpms_w.txt
rm -rf /tmp/base_rpm.txt
rm -rf /tmp/kolla_wallaby/
rm -rf /tmp/w_rpm_list.txt

yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

yum install -y centos-release-openstack-wallaby
yum install -y python3
rm -rf /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo
rm -rf /etc/yum.repos.d/CentOS-Messaging-rabbitmq.repo

python3 -m pip install kolla
#yum remove centos-release-openstack-wallaby openstack-kolla
#yum makecache;yum install centos-release-openstack-wallaby
#yum install openstack-kolla
#build images locally and get list of rpms that need to be cached.
kolla-build -t binary --openstack-release wallaby --tag wallaby --registry rpm_repo --skip-existing rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove

for i in `docker images |grep rpm_repo |awk '{print $3}'`;do docker run --rm -u root -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -ti $i bash -c "rpm -qa >>/tmp/all_rpms_w.txt";done
#add openstack kolla rpms to cache repo
for i in $openstack_kolla_pkgs;do echo $i >>/tmp/all_rpms_w.txt;done

cat /tmp/all_rpms_w.txt |sort |sort -u >/tmp/w_rpm_list.txt

docker run --rm -u root -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/:/tmp/ -ti rpm_repo/kolla/centos-binary-base:wallaby bash -c "rpm -qa >/tmp/base_rpm.txt"

cat /tmp/w_rpm_list.txt /tmp/base_rpm.txt |sort |uniq -u >/tmp/to_be_download_w.txt

mkdir -p /tmp/kolla_wallaby

docker run -u root -v /tmp/:/tmp/ --rm -ti rpm_repo/kolla/centos-binary-base:wallaby -v /var/run/docker.sock:/var/run/docker.sock bash -c "download_rpms.sh"
#create local rpm repo
createrepo /tmp/kolla_wallaby/
cd /tmp/kolla_wallaby && repo2module -s stable  . modules.yaml && modifyrepo_c --mdtype=modules modules.yaml repodata/
cd /tmp/; tar czvf /tmp/kolla_w_rpm_repo.tar.gz ./kolla_wallaby/
echo "kolla rpm cache repo is built at /tmp/kolla_w_rpm_repo.tar.gz"

#clean docker images
for i in `docker images |grep rpm_repo|awk '{print $3}'`;do docker rmi -f $i;done

if [ -f /Dockerfile.j2 ];then
   cp /Dockerfile.j2 /usr/share/kolla/docker/base/
else
  echo "no centos-binary-base dockerfile in /tmp to copy"
  exit 1
fi
kolla-build -t binary --openstack-release wallaby --tag wallaby ^base
docker  save localhost/kolla/centos-binary-base:wallaby > centos-binary-base-w.tar