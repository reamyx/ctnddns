#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#服务状态测试过程,返回测试状态
pidof "nginx" && {
    [ -f "./Fcgiwrap.Enabled" ] && { pidof "fcgiwrap" || exit; }
    [ -f "./LocalGW.Enabled"  ] && { ../uwsgi/PeriodicST-state-check.sh || exit; }
    exit 0; }
