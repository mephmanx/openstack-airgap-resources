FROM centos:latest
MAINTAINER mephmanx@gmail.com
COPY init.sh /root
RUN chmod 777 /root/init.sh
COPY download_rpms.sh /root
RUN chmod 777 /root/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /root/Dockerfile.j2
RUN yum install -y curl && curl -sSL https://get.docker.com/ | sh
ENTRYPOINT ["./root/init.sh"]