FROM tgagor/centos-stream
MAINTAINER mephmanx@gmail.com
COPY init.sh /
RUN chmod 777 /init.sh
COPY download_rpms.sh /
RUN chmod 777 /download_rpms.sh
COPY Dockerfile.j2 /
RUN chmod 777 /Dockerfile.j2
ENTRYPOINT ["./init.sh"]