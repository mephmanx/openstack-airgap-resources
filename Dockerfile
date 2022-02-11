FROM tgagor/centos-stream
MAINTAINER mephmanx@gmail.com
COPY init.sh /out
RUN chmod 777 /out/init.sh
COPY download_rpms.sh /out
RUN chmod 777 /out/download_rpms.sh
COPY Dockerfile.j2 /root
RUN chmod 777 /out/Dockerfile.j2

RUN yum install -y modulemd-tools yum-utils epel-release python3 git curl yum-utils
RUN curl -sSL https://get.docker.com/ | sh
RUN python3 -m pip install kolla

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["./out/init.sh"]