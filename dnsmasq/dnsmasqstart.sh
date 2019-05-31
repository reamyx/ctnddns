#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

MAPEN="./NameMap.Enabled"

#先行服务停止
for ID in {1..20}; do pkill "^dnsmasq$" || break; sleep 0.5; done
[ -f "$MAPEN" ] && { rm -f "$MAPEN"; ../nginx/nginxstart.sh "stop"; }
[ "$1" == "stop" ] && exit 0

#DDNS注册
#DDNSREG="./PeriodicRT-ddns-update"
#[ -f "$DDNSREG" ] && ( chmod +x "$DDNSREG"; setsid "$DDNSREG" & )

REGIF="eth0"
STCHOST="./dnsmasq.hosts"
MAPHOST="./namemapv2.hostsv4"

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"

SRVPORT="$( echo "$SRVCFG" | jq -r ".dnsmasq.srvport|numbers" )"
NAMEMAP="$( echo "$SRVCFG" | jq -r ".dnsmasq.namemap|strings" )"
URLPSWD="$( echo "$SRVCFG" | jq -r ".dnsmasq.urlpswd|strings" )"
WEBPORT="$( echo "$SRVCFG" | jq -r ".dnsmasq.webport|numbers" )"
DOMAINS="$( echo "$SRVCFG" | jq -r ".dnsmasq.domains|strings" )"

SRVPORT="${SRVPORT:-53}"
WEBPORT="${WEBPORT:-1253}"
DOMAINS="${DOMAINS:-moon.zmn}"
URLPSWD="${URLPSWD:-abc000}"

REGADDR="$( ip -o addr show "$REGIF" | awk '{sub("/.*$","",$4); print $4}' )"
REGADDR="${REGADDR:-$(hostname)}"

FWRLPM=( -p tcp -m tcp --dport "$WEBPORT" -m conntrack --ctstate NEW -j ACCEPT )

#服务环境初始化
iptables -t filter -D SRVLCH "${FWRLPM[@]}"

#条件配置namemap网关服务,TCP1253访问网关服务,需要外部防火墙放行
[[ "$NAMEMAP" =~ ^"YES"|"yes"$ ]] && (
    iptables -t filter -A SRVLCH "${FWRLPM[@]}"
    ln -sf "../../dnsmasq/namemapv2.sh" ../nginx/cgibin/Shell-CGI-namemapv2
    echo 'rewrite ^/namemapv2$ /Shell-CGI-namemapv2 last;' > ../nginx/nginx/namemapv2.default.rewrite
    SRVCFG="{ \"nginx\": { \"fcgiwrap\": \"yes\", \"srvport\": $WEBPORT } }"
    echo "$URLPSWD" > "$MAPEN"; SRVCFG="$SRVCFG" setsid ../nginx/nginxstart.sh & )

#启动dnsmasq服务
touch "$STCHOST" "$MAPHOST" ./dyn.server ./chn.record \
      ./txt.record ./srv.record ./ptr.record
echo "\
interface=*
no-dhcp-interface=*
no-resolv
strict-order
local=/$DOMAINS/
domain=$DOMAINS
domain-needed
local-ttl=2
no-hosts
expand-hosts
addn-hosts=$PWD/$STCHOST
addn-hosts=$PWD/$MAPHOST
servers-file=$PWD/dyn.server
conf-file=$PWD/chn.record
conf-file=$PWD/txt.record
conf-file=$PWD/srv.record
conf-file=$PWD/ptr.record
address=/ddns.local/$REGADDR
" > ./dnsmasq.conf
exec dnsmasq -k -C "./dnsmasq.conf" -p "$SRVPORT"

exit 127

