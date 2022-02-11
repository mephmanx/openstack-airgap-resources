FROM tgagor/centos-stream
MAINTAINER mephmanx@gmail.com
COPY init.sh /tmp
RUN chmod 777 /tmp/init.sh
COPY download_rpms.sh /root
RUN chmod 777 /tmp/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /tmp/Dockerfile.j2
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["./tmp/init.sh"]