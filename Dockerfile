FROM tgagor/centos-stream
MAINTAINER mephmanx@gmail.com
COPY init.sh /
RUN chmod 777 /init.sh
COPY download_rpms.sh /tmp
RUN chmod 777 /tmp/download_rpms.sh
COPY Dockerfile.j2 /tmp
RUN chmod 777 /tmp/Dockerfile.j2
ENTRYPOINT ["./init.sh"]