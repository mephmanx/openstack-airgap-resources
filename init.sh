#!/bin/bash

exec 1>/out/openstack-build.log 2>&1
set -x

# clear environment for legacy installation
if [ `rpm -qa |grep kolla` ];then
yum remove openstack-kolla
fi

OPENSTACK_VERSION=$1

yum install -y wget modulemd-tools yum-utils epel-release python3 git curl yum-utils centos-release-openstack-$OPENSTACK_VERSION
yum install -y openstack-kolla

echo "Building resources using openstack version -> $OPENSTACK_VERSION"
sleep 5
#build kolla-build offline rpms cache repo
openstack_kolla_pkgs="openstack-kolla git-core less libedit openssh openssh-clients python-oslo-i18n-lang python3-GitPython python3-babel python3-debtcollector python3-docker python3-funcsigs python3-gitdb python3-importlib-metadata python3-jinja2  python3-markupsafe  python3-netaddr python3-oslo-config python3-oslo-i18n python3-pbr  python3-pytz python3-rfc3986 python3-smmap python3-stevedore python3-websocket-client python3-wrapt python3-zipp"
#install repo build tools
if [[ "$OPENSTACK_VERSION" == "xena" ]]; then
  pip3 install jinja2==3.0.3
  sed -i 's#centos8-amd64#centos/8/x86_64/#' /usr/share/kolla/docker/base/mariadb.repo
fi

#build images locally and get list of rpms that need to be cached.
if [[ "$OPENSTACK_VERSION" == "wallaby" ]]; then
  kolla-build --skip-existing -t binary --openstack-release "$OPENSTACK_VERSION" --tag "$OPENSTACK_VERSION" --registry rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove murano panko
elif [[ "$OPENSTACK_VERSION" == "xena" ]]; then
  kolla-build --skip-existing -t binary --openstack-release "$OPENSTACK_VERSION" --tag "$OPENSTACK_VERSION" --registry rpm_repo barbican ceilometer cinder cron designate dnsmasq elasticsearch etcd glance gnocchi grafana hacluster haproxy heat horizon influxdb iscsid  keepalived keystone kibana logstash magnum  manila mariadb memcached multipathd neutron nova octavia openstack-base openvswitch  placement qdrouterd rabbitmq redis  swift telegraf trove murano
fi

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

if [[ "$OPENSTACK_VERSION" == "wallaby" ]]; then
  ####  objects needed by exporter images, versions are specific to openstack versions
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_memcached_exporter.tar.gz https://github.com/prometheus/memcached_exporter/releases/download/v0.6.0/memcached_exporter-0.6.0.linux-amd64.tar.gz
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_haproxy_exporter.tar.gz https://github.com/prometheus/haproxy_exporter/releases/download/v0.10.0/haproxy_exporter-0.10.0.linux-amd64.tar.gz
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_elasticsearch_exporter.tar.gz https://github.com/prometheus-community/elasticsearch_exporter/releases/download/v1.1.0/elasticsearch_exporter-1.1.0.linux-amd64.tar.gz
elif [[ "$OPENSTACK_VERSION" == "xena" ]]; then
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_memcached_exporter.tar.gz https://github.com/prometheus/memcached_exporter/releases/download/v0.6.0/memcached_exporter-0.6.0.linux-amd64.tar.gz
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_haproxy_exporter.tar.gz https://github.com/prometheus/haproxy_exporter/releases/download/v0.10.0/haproxy_exporter-0.10.0.linux-amd64.tar.gz
  wget -O /out/kolla_"$OPENSTACK_VERSION"/prometheus_elasticsearch_exporter.tar.gz https://github.com/prometheus-community/elasticsearch_exporter/releases/download/v1.2.1/elasticsearch_exporter-1.2.1.linux-amd64.tar.gz
  wget -O /out/kolla_"$OPENSTACK_VERSION"/clustercheck.sh  https://src.fedoraproject.org/rpms/mariadb/raw/10.3/f/clustercheck.sh
fi

cd /out; tar czvf /out/kolla_"$OPENSTACK_VERSION"_rpm_repo.tar.gz ./kolla_"$OPENSTACK_VERSION"/
echo "kolla rpm cache repo is built at /root/kolla_"$OPENSTACK_VERSION"_rpm_repo.tar.gz"

#clean docker base images
for i in `docker images |grep centos-binary-base|awk '{print $3}'`;do docker rmi $i;done

if [ -f /root/Dockerfile.j2 ];then
  sed -i "s/{OPENSTACK_VERSION}/$OPENSTACK_VERSION/g" /root/Dockerfile.j2
  if [ "$OPENSTACK_VERSION" == "wallaby" ]; then
    sed -i "s/{CEPH_VERSION}/nautilus/g" /root/Dockerfile.j2
  fi
  if [ "$OPENSTACK_VERSION" == "xena" ]; then
    sed -i "s/{CEPH_VERSION}/pacific/g" /root/Dockerfile.j2
  fi

  cp /root/Dockerfile.j2 /usr/share/kolla/docker/base/
else
  echo "no centos-binary-base dockerfile in /tmp to copy"
  exit 1
fi
kolla-build -t binary --openstack-release "$OPENSTACK_VERSION" --tag "$OPENSTACK_VERSION" ^base
docker save kolla/centos-binary-base:"$OPENSTACK_VERSION" > /out/centos-binary-base-"$OPENSTACK_VERSION".tar
sed -i "s/{OPENSTACK_VERSION}/$OPENSTACK_VERSION/g" /root/globals.yml
cp /root/globals.yml /out/globals.yml
