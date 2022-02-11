#!/bin/bash

#build kolla-build offline rpms cache repo

openstack_kolla_pkgs="openstack-kolla git-core less libedit openssh openssh-clients python-oslo-i18n-lang python3-GitPython python3-babel python3-debtcollector python3-docker python3-funcsigs python3-gitdb python3-importlib-metadata python3-jinja2  python3-markupsafe  python3-netaddr python3-oslo-config python3-oslo-i18n python3-pbr  python3-pytz python3-rfc3986 python3-smmap python3-stevedore python3-websocket-client python3-wrapt python3-zipp"
#install repo build tools

#fix centos 8 ceph issue
sed -e '447s!^$!RUN sed -e "s/#baseurl/baseurl/" -e "s/mirrorlist/#mirrorlist/" -e "s/mirror.*.org/vault.centos.org/" -i /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo!' -i /usr/local/share/kolla/docker/base/Dockerfile.j2

#fix centos 8 rpm install issue on openstack-base image
sed -i "s/'python3-sqlalchemy-collectd',//" /usr/local/share/kolla/docker/openstack-base/Dockerfile.j2

#build images locally and get list of rpms that need to be cached.
kolla-build --skip-existing -t binary --openstack-release wallaby --tag wallaby --registry rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove

#rm -f /root/all_rpms_w.txt /root/w_rpm_list.txt /root/base_rpm.txt /root/to_be_download_w.txt

for i in `docker images |grep rpm_repo|grep -v centos-binary-base |awk '{print $3}'`; do
  docker run --rm -u root -v /out/file-work:/out -v /var/run/docker.sock:/var/run/docker.sock  $i bash -c "rpm -qa >>/out/all_rpms_w.txt";
done
#add openstack kolla rpms to cache repo
for i in $openstack_kolla_pkgs;do echo $i >>/out/file-work/all_rpms_w.txt;done

cat /out/file-work/all_rpms_w.txt |sort |sort -u >/out/file-work/w_rpm_list.txt

docker run --rm -u root -v /out/file-work:/root -v /var/run/docker.sock:/var/run/docker.sock  kolla/centos-binary-base:wallaby bash -c "rpm -qa >/out/base_rpm.txt"

cat /out/file-work/w_rpm_list.txt /out/file-work/base_rpm.txt |sort |uniq -u >/out/file-work/to_be_download_w.txt

mkdir -p /out/file-work/kolla_wallaby

docker run -u root -v /out/file-work:/out -v /var/run/docker.sock:/var/run/docker.sock --rm  kolla/centos-binary-base:wallaby bash -c "/out/download_rpms.sh"
#create local rpm repo
createrepo /out/file-work/kolla_wallaby/
cd /out/file-work/kolla_wallaby && repo2module -s stable  . modules.yaml && modifyrepo_c --mdtype=modules modules.yaml repodata/
cd /out/file-work/; tar czvf /out/kolla_w_rpm_repo.tar.gz ./kolla_wallaby/
echo "kolla rpm cache repo is built at /root/kolla_w_rpm_repo.tar.gz"

#clean docker images
#for i in `docker images |grep rpm_repo|awk '{print $3}'`;do docker rmi $i;done

if [ -f /root/Dockerfile.j2 ];then
   cp /root/Dockerfile.j2 /usr/local/share/kolla/docker/base/
else
  echo "no centos-binary-base dockerfile in /tmp to copy"
  exit 1
fi
kolla-build -t binary --openstack-release wallaby --tag wallaby ^base
docker save -v /var/run/docker.sock:/var/run/docker.sock kolla/centos-binary-base:wallaby > /out/centos-binary-base-w.tar

ls -al /out/file-out
ls -al /out