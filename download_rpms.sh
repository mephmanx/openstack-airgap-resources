#!/bin/bash

OPENSTACK_VERSION=$1
#this script need to be put on /root directory on build server
#this script is to be executed inside of centos-binary-base image to download rpms

yum install -y modulemd-tools yum-utils

if [ $OPENSTACK_VERSION == "wallaby" ];then
   dnf config-manager --enable centos-ceph-nautilus --enable centos-nfv-openvswitch --enable centos-advanced-virtualization --enable powertools --enable rabbitmq_rabbitmq-server --enable rabbitmq_rabbitmq-erlang --enable centos-opstools --enable influxdb --enable elasticsearch-kibana-logstash-7.x --enable grafana --enable ha
elif [ $OPENSTACK_VERSION == "xena" ];then
    dnf config-manager --enable centos-ceph-pacific --enable centos-nfv-openvswitch --enable centos-advanced-virtualization --enable powertools --enable rabbitmq_rabbitmq-server --enable rabbitmq_rabbitmq-erlang --enable centos-opstools --enable influxdb --enable elasticsearch-kibana-logstash-7.x --enable grafana --enable ha --enable mariadb
fi

dnf module enable mod_auth_openidc -y

mkdir -p /out/kolla_"$OPENSTACK_VERSION"

cd /out/kolla_"$OPENSTACK_VERSION"

for i in `cat /out/to_be_download_"$OPENSTACK_VERSION".txt`;do yumdownloader $i;done

dnf config-manager --enable epel
yumdownloader pv python3-boto3
