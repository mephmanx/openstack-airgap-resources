FROM quay.io/centos/centos:stream8
MAINTAINER mephmanx@gmail.com
RUN mkdir /out
COPY globals.yml /out
RUN chmod 777 /out/globals.yml
COPY init.sh /
RUN chmod 777 /init.sh
COPY download_rpms.sh /root
RUN chmod 777 /root/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /root/Dockerfile.j2
COPY globals.yml /root
RUN chmod 777 /root/globals.yml
RUN curl -sSL https://get.docker.com/ | sh

ENTRYPOINT ["./init.sh"]
