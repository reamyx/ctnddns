#官方centos7镜像初始化,镜像TAG: ctnddns

FROM        imginit
LABEL       function="ctnddns"

#添加本地资源
ADD     dnsmasq     /srv/dnsmasq/
ADD     nginx       /srv/nginx/

WORKDIR /srv/dnsmasq

#功能软件包
RUN     set -x \
        && cd ../imginit \
        && mkdir -p installtmp \
        && cd installtmp \
        \
        && yum -y install dnsmasq bind-utils openssl nginx httpd-tools fcgi spawn-fcgi \
        && yum -y install gcc make automake fcgi-devel zlib-devel \
        \
        && curl https://codeload.github.com/gnosek/fcgiwrap/zip/master -o fcgiwrap.zip \
        && unzip fcgiwrap.zip \
        && cd fcgiwrap-master \
        && autoreconf -i \
        && ./configure \
        && make \
        && make install \
        && cd - \
        \
        && cd ../ \
        && yum -y history undo last \
        && yum clean all \
        && rm -rf installtmp /tmp/* \
        && find ../ -name "*.sh" -exec chmod +x {} \;


ENV       ZXDK_THIS_IMG_NAME    "ctnddns"
ENV       SRVNAME               "dnsmasq"

# ENTRYPOINT CMD
CMD [ "../imginit/initstart.sh" ]
