#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

FWPEN="./Fcgiwrap.Enabled"
LGWEN="./LocalGW.Enabled"

#先行服务停止
for ID in {1..20}; do
pkill -f "nginx: master" || pkill "^fcgiwrap$" || break; sleep 0.5; done
rm -rf "$FWPEN"; [ -f "$LGWEN" ] && { rm -rf "$LGWEN"; ../uwsgi/uwsgistart.sh "stop"; }
[ "$1" == "stop" ] && exit 0

#DDNS注册
DDNSREG="./PeriodicRT-ddns-update"
[ -f "$DDNSREG" ] && ( chmod +x "$DDNSREG"; setsid "$DDNSREG" & )

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"

SRVPORT="$( echo "$SRVCFG" | jq -r ".nginx.srvport|numbers" )"
FCGIWRAP="$( echo "$SRVCFG" | jq -r ".nginx.fcgiwrap|strings" )"

SRVPORT="${SRVPORT:-1280}"

#服务运行环境初始化,服务安全配置,辅助服务标记复位
mkdir -p nginx webroot logs cgibin
chown -R nginx:nginx nginx webroot logs
chmod -R 644 nginx webroot logs
chmod    744 nginx webroot logs

#启动简易CGI网关,测试页重写在cgitest.default.rewrite文件中(*.default.rewrite)    
[[ "$FCGIWRAP" =~ ^"YES"|"yes"$ ]] && {
    touch "$FWPEN"; spawn-fcgi -d ./cgibin -f fcgiwrap -F 2 -a 127.0.0.1 -p 8001; }

#配置端口并启动nginx服务
echo "listen $SRVPORT;" > ./nginx/default.server.port
exec nginx -p "./nginx" -c "nginx.conf" -g "daemon off;"

exit 127
