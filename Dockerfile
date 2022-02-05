FROM alpine:latest
MAINTAINER mephmanx@gmail.com
COPY init.sh /root
RUN chmod 777 /root/init.sh
COPY download_rpms.sh /root
RUN chmod 777 /root/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /root/Dockerfile.j2
ENTRYPOINT ["./root/init.sh"]