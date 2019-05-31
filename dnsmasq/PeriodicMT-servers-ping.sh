#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#dnsmaq动态服务器(级联)存活检测和启停,周期性PING测试使用特定前缀"#>>>"注释的或当前
#的"子域配置项"中的主机地址并根据测试结果执行行激活或去活操作.
SFL="./dyn.server"
exec 10<>"$SFL"
flock -x -n 10 || { exec 10<&-; exit 1; }

RZT="$( awk -F"=" '$1~/^[[:space:]]*(#>>>)?[[:space:]]*(rev-)?server$/&&\
        $2~/^\/.*\//{s=$2;gsub(".*/","",s);gsub("[^0-9.].*$","",s);\
        s=system("ping -nq -c 2 -W 1 -i 0.1 "s" &>/dev/null")?"#>>> ":"";\
        gsub("^[[:space:]#>]*",s,$0)}{print}' $SFL )"
echo "$RZT" > "$SFL"; echo >> "$SFL"

pkill -SIGHUP "dnsmasq"

exec 10<&-
