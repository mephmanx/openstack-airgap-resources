#!/bin/bash

#this script need to be put on /root directory on build server
#this script is to be executed inside of centos-binary-base image to download rpms

yum install -y modulemd-tools yum-utils

dnf config-manager --enable powertools --enable rabbitmq_rabbitmq-server --enable rabbitmq_rabbitmq-erlang --enable influxdb --enable elasticsearch-kibana-logstash-7.x --enable grafana --enable ha

dnf module enable mod_auth_openidc -y

mkdir -p /tmp/kolla_wallaby

cd /tmp/kolla_wallaby

for i in `cat /tmp/to_be_download_w.txt`;do yumdownloader $i;done

dnf config-manager --enable epel
yumdownloader pv python3-boto3