#!/bin/bash

OPENSTACK_VERSION=$1
echo "Building resources using openstack version -> $OPENSTACK_VERSION"
sleep 5
#build kolla-build offline rpms cache repo
openstack_kolla_pkgs="openstack-kolla git-core less libedit openssh openssh-clients python-oslo-i18n-lang python3-GitPython python3-babel python3-debtcollector python3-docker python3-funcsigs python3-gitdb python3-importlib-metadata python3-jinja2  python3-markupsafe  python3-netaddr python3-oslo-config python3-oslo-i18n python3-pbr  python3-pytz python3-rfc3986 python3-smmap python3-stevedore python3-websocket-client python3-wrapt python3-zipp"
#install repo build tools

#fix centos 8 ceph issue
sed -e '447s!^$!RUN sed -e "s/#baseurl/baseurl/" -e "s/mirrorlist/#mirrorlist/" -e "s/mirror.*.org/vault.centos.org/" -i /etc/yum.repos.d/CentOS-Ceph-Nautilus.repo!' -i /usr/local/share/kolla/docker/base/Dockerfile.j2

#fix centos 8 rpm install issue on openstack-base image
sed -i "s/'python3-sqlalchemy-collectd',//" /usr/local/share/kolla/docker/openstack-base/Dockerfile.j2

#build images locally and get list of rpms that need to be cached.
kolla-build --skip-existing -t binary --openstack-release "$OPENSTACK_VERSION" --tag "$OPENSTACK_VERSION" --registry rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove

for i in `docker images |grep rpm_repo|grep -v centos-binary-base |awk '{print $3}'`; do
  docker run --rm -u root -v /out:/out -v /var/run/docker.sock:/var/run/docker.sock  $i bash -c "rpm -qa >>/out/all_rpms_$OPENSTACK_VERSION.txt";
done
#add openstack kolla rpms to cache repo
for i in $openstack_kolla_pkgs;do echo $i >>/out/all_rpms_"$OPENSTACK_VERSION".txt;done

cat /out/all_rpms_"$OPENSTACK_VERSION".txt |sort |sort -u >/out/"$OPENSTACK_VERSION"_rpm_list.txt

docker run --rm -u root -v /out:/out -v /var/run/docker.sock:/var/run/docker.sock  rpm_repo/kolla/centos-binary-base:"$OPENSTACK_VERSION" bash -c "rpm -qa >/out/base_rpm.txt"

cat /out/"$OPENSTACK_VERSION"_rpm_list.txt /out/base_rpm.txt |sort |uniq -u >/out/to_be_download_"$OPENSTACK_VERSION".txt

mkdir -p /out/kolla_"$OPENSTACK_VERSION"
cp /root/download_rpms.sh /out
docker run -u root -v /out:/out -v /var/run/docker.sock:/var/run/docker.sock --rm  rpm_repo/kolla/centos-binary-base:"$OPENSTACK_VERSION" bash -c "/out/download_rpms.sh $OPENSTACK_VERSION"
#create local rpm repo
createrepo /out/kolla_"$OPENSTACK_VERSION"/
cd /out/kolla_"$OPENSTACK_VERSION" && repo2module -s stable  . modules.yaml && modifyrepo_c --mdtype=modules modules.yaml repodata/
cd /out; tar czvf /out/kolla_"$OPENSTACK_VERSION"_rpm_repo.tar.gz ./kolla_"$OPENSTACK_VERSION"/
echo "kolla rpm cache repo is built at /root/kolla_"$OPENSTACK_VERSION"_rpm_repo.tar.gz"

#clean docker images
#docker rmi $(docker images | grep 'rpm_repo')

if [ -f /root/Dockerfile.j2 ];then
   cp /root/Dockerfile.j2 /usr/local/share/kolla/docker/base/
else
  echo "no centos-binary-base dockerfile in /tmp to copy"
  exit 1
fi
kolla-build -t binary --openstack-release "$OPENSTACK_VERSION" --tag "$OPENSTACK_VERSION" ^base
docker save kolla/centos-binary-base:"$OPENSTACK_VERSION" > /out/centos-binary-base-"$OPENSTACK_VERSION".tar
cp /root/globals.yml /out/globals.yml
