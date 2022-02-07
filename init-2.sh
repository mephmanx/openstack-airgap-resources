#!/bin/bash

IFS=$'\n'
for repo in $(ls /etc/yum.repos.d);
do
  sed -e "s/#baseurl/baseurl/" -e "s/mirrorlist/#mirrorlist/" -e "s/mirror.*.org/vault.centos.org/" -i /etc/yum.repos.d/$repo
done

#yum install -y modulemd-tools yum-utils epel-release python3 git
yum install -y curl
#curl --unix-socket /var/run/docker.sock http://localhost/version
curl -sSL https://get.docker.com/ | sh
yum install -y yum-utils
#yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
#yum install -y docker-ce docker-ce-cli containerd.io
curl --unix-socket /var/run/docker.sock http://localhost/version