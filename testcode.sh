#!/bin/env sh
exit 0

#说明: 外部名称代理服务器位于公有云,通过VPN连接内部名称注册服务器

#外部名称解析 ddns00 brx.600vps.com,转发业务名称查询到本地服务器
SRVCFG='{"initdelay":2,"workstart":"./dnsmasqstart.sh",
"workwatch":15,"workintvl":3,"firewall":
{"tcpportpmt":"53","udpportpmt":"53","icmppermit":"yes"},
"ovpnser":{"enable":"yes"},"dnsmasq":{"namemap":"yes",
"domains":"brx.600vps.com"}}'; \
docker stop ddns00; docker rm ddns00; \
docker container run --detach --restart always \
--name ddns00 --hostname ddns00 \
--network brn01 --cap-add NET_ADMIN \
--device /dev/ppp --device /dev/net/tun \
--volume /etc/localtime:/etc/localtime:ro \
--publish 53:53/udp --publish 1253:1253/tcp \
--publish 1258:1258/tcp --env "SRVCFG=$SRVCFG" \
registry.cn-hangzhou.aliyuncs.com/zhixia/imginit:dnsmasq

docker container exec -it ddns00 bash
curl http://brxa.600vps.com:1253/namemapv2?list


#本地名称注册 ddns192 ln.600vps.com,为etcd集群配置srv发现
SRVCFG='{"initdelay":2,"workstart":"./dnsmasqstart.sh",
"workwatch":15,"workintvl":3,"firewall":
{"tcpportpmt":"53","udpportpmt":"53","icmppermit":"yes"},
"ovpnclt":{"enable":"yes","rmtaddr":"brxa.600vps.com",
"username":"ddns01","password":"abc000"},
"dnsmasq":{"namemap":"yes","domains":"ln.600vps.com"}}'; \
docker stop ddns192; docker rm ddns192; \
docker container run --detach --restart always \
--name ddns192 --hostname ddns192 \
--network imvn --cap-add NET_ADMIN \
--device /dev/ppp --device /dev/net/tun \
--volume /etc/localtime:/etc/localtime:ro \
--env "SRVCFG=$SRVCFG" --ip 192.168.15.192 \
registry.cn-hangzhou.aliyuncs.com/zhixia/imginit:dnsmasq

docker container exec -it ddns192 bash
curl http://192.168.15.192:1253/namemapv2?list
