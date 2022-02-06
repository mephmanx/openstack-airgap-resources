FROM tgagor/centos-stream
MAINTAINER mephmanx@gmail.com
COPY init.sh /root
RUN chmod 777 /root/init.sh
COPY init-2.sh /root
RUN chmod 777 /root/init-2.sh
COPY download_rpms.sh /root
RUN chmod 777 /root/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /root/Dockerfile.j2
RUN touch /var/run/docker.sock
RUN chmod 777 /var/run/docker.sock
ENTRYPOINT ["./root/init-2.sh"]