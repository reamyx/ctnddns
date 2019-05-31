#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#名称映射数据库及映射表名称
TBNMMP="namemap"
XCSTDB="./namemapv2.db"
DHOSTS="./namemapv2.hostsv4"
LOCKFL="./Flush.last"; touch "$LOCKFL"

#持锁操作防止多实例重入
exec 5<>"$LOCKFL"; flock -x -n 5 || exit 1

#映射数据库
[ -f "$XCSTDB" ] || exit 2

#控制刷新频次
NOW="$( date "+%s" )"; read -t 1 -u 5 LAST; (( LAST + 5 > NOW )) && sleep 5

#清除过期记录,生成并写入新的hosts文件内容
echo "BEGIN;
DELETE FROM $TBNMMP WHERE mapttl>0 AND strftime(\"%s\")-(unixtm+mapttl)>0;
SELECT target||\" \"||name FROM $TBNMMP WHERE
maptype==\"V4HOST\" OR maptype==\"V4CLUT\"; COMMIT;" | \
sqlite3 -cmd ".timeout 3000" "$XCSTDB" > "$DHOSTS"

#relaod
pkill -SIGHUP "dnsmasq"

date "+%s" > "$LOCKFL"

exit 0
