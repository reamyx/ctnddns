#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" 
cd "$(dirname "$0")"; exec 4>&1; ECHO(){ echo "${@}" >&4; }

#名称映射数据库及映射表名称
TBNMMP="namemap"
XCSTDB="../../dnsmasq/namemapv2.db"
HFLUSH="../../dnsmasq/PeriodicRT-mapflush.sh"
MAPEN="../../dnsmasq/NameMap.Enabled"

#清除映射表内容
[ "$1" == "cleandb" ] && sqlite3 "$XCSTDB" "DELETE FROM $TBNMMP;"
[ -n "$1" ] && exit 0

#测试并在必要时重建数据库
[ -f "$XCSTDB" ] || {
    echo "
    CREATE TABLE $TBNMMP(
    name     CHAR(16) NOT NULL,
    maptype  CHAR(8)  NOT NULL,
    target   CHAR(40) NOT NULL,
    unixtm   INTEGER  NOT NULL,
    mapttl   INTEGER  );" | sqlite3 "$XCSTDB"; }

#页面内容设置方法和渲染,如果可以这么叫的话^_^
HEAD="Status: 200 OK"; MSGS=()
HEADSET() { HEAD="$1"; }
MSGAPND() { MSGS=( "${MSGS[@]}" "$1" ); }
RESPONSE() {
ECHO "\
$HEAD
Content-type: text/html

<!DOCTYPE html>
<html>
  <head>
    <title>NameMapV2</title>
  </head>
  <body>"
local MSG=""; for MSG in "${MSGS[@]}"; do
    ECHO "    <p>$MSG</p>"; done
ECHO "\
    <p>NameMapV2, Powered by Zhixia, reamyx@126.com</p>
  </body>
</html>
"; exit 0; }

HELPMSG() {
MSGAPND
MSGAPND ">> 请求方法: 仅支持POST或GET方法提供参数字串."
MSGAPND ">> 参数解密: 参数串前64位(8byte)为iv串,其余为aes-128-cbc加密的参数数据(base64串)."
MSGAPND ">> 参数格式: 解密后的参数数据为单一JSON对象数组,数组中非对象元素会被忽略."
MSGAPND ">> 对象元素: .name, 指定添加或更新的主机或集群名称,不大于16字符."
MSGAPND ">> 对象元素: .maptype, 指定名称映射类型,当前仅实现IPv4相关操作."
MSGAPND ">> 对象元素: .target, 映射目标,根据映射类型可为IPv4或IPv6地址串,缺省使用请求源地址."
MSGAPND ">> 对象元素: .mapttl, 映射时长,超时后自动清除当前映射,单位秒,缺省:主机0(不超时),集群35."
MSGAPND ">> 映射类型: \"V4HOST\":主机地址IPv4,\"V4CLUT\":集群地址IPv4,\"REMOVE\":移除指定名称."; }

##########################  主程序  ##########################
RQPM=""; SPMS=(); FLUSH=""; KEY=""

#确定请求方法并提取更新源数据,非期望请求方法时返回错误.
case "$REQUEST_METHOD" in
"GET"  ) RQPM="$QUERY_STRING";;
"POST" ) read -t 2 RQPM;;
*      ) HEADSET "Status: 405 Method Not Allowed"
         MSGAPND "请求错误: 不被支持的请求方法."
         HELPMSG; RESPONSE;;
esac

#返回当前记录状态
[ "$RQPM" == "list" ] && {
    MSGAPND "当前记录($(date +%F/%T/%Z )):"
    MSGAPND "名称             类型     目标             存活     到期    "
    TMP="$( sqlite3 "$XCSTDB" "SELECT name||\" \"||maptype||\" \"||target||\
    \" \"||mapttl||\" \"||((unixtm+mapttl)-strftime(\"%s\")) FROM $TBNMMP;" | sort )"
    [ -z "$TMP" ] && LNS=0 || LNS="$( echo "$TMP" | wc -l )"
    for((ID=0;ID<LNS;ID++)); do
        MSGAPND "$( echo "$TMP" | awk -v ln=$((ID+1)) \
        'NR==ln{printf("%-16s %-8s %-16s %-8s %-8s\n",$1,$2,$3,$4,$5)}' )"; done
    MSGAPND "计数: $LNS"; RESPONSE; }

#更新源数据为空时可提供交互式页面或操作指示
(( "${#RQPM}" < 8  )) && {
    HEADSET "Status: 202 Accepted"
    MSGAPND "需要提供完整参数(POST,GET)."
    HELPMSG; RESPONSE; }

#分离目标参数,解密后的参数必须是一个JSON对象数组
[ "${RQPM::8}" == "SIMPLEPM" ] && {
    SPMS=( $( echo "${RQPM:8}" | awk -F ";" '{print "-"$2,"-"$3,"-"$4,"-"$5}' ) )
    RQPM="[{ \"name\": \"${SPMS[0]:1}\", \"maptype\": \"${SPMS[1]:1}\",
             \"target\": \"${SPMS[2]:1}\", \"mapttl\": \"${SPMS[3]:1}\" }]"
true; } || {
    [ -r "$MAPEN" ] && read -t 1 KEY <"$MAPEN"; KEY="${KEY:-abc000}"; KIV="{RQPM::8}"
    RQPM="$( echo "${RQPM:8}" | openssl enc -d -aes-128-cbc -a -K "$KEY" -iv "$KIV" | \
          jq -scM ".[0]|arrays" )"; }

#请求数量测试
PCNT="$( echo "$RQPM" | jq -cM "length" )"
(( PCNT < 1 )) && {
        HEADSET "Status: 412 Precondition Failed"
        MSGAPND "参数错误: 操作请求缺失或格式错误."; HELPMSG; RESPONSE; };

#请求有效时参数组遍历,执行名称映射和组装页面消息
HEADSET "Status: 200 OK"; MSGAPND "TIME: $(date +%F/%T/%Z )"
OPCT=0; OPOK=0;for((ID=0;ID<PCNT;ID++)); do
    TMP="$( echo "$RQPM" | jq -cM ".[$ID]|objects" )"
    [ -z "$TMP" ] && continue; (( OPCT++ ))
    
    #名称检查
    NAME="$( echo "$TMP" | jq -rcM ".name|strings" )"
    [ -z "$NAME" ] && { MSGAPND "[ $ID ] 名称缺失,已忽略."; continue; }
    
    #映射类型检查
    MAPT="$( echo "$TMP" | jq -rcM ".maptype|strings" )"
    echo "V4HOST V4CLUT REMOVE" | grep -Ewq "$MAPT" || {
        MSGAPND "[ $ID ] 不支持的映射类型,已忽略."; continue; }
    
    #移除操作
    [ "$MAPT" == "REMOVE" ] && {
        echo "DELETE FROM $TBNMMP WHERE name==\"$NAME\";" | sqlite3 -cmd ".timeout 3000" "$XCSTDB"
        MSGAPND "[ $ID ] 名称映射移除( NAME: $NAME )."; FLUSH="YES"; (( OPOK++ )); continue; }
    
    #映射目标检查
    TAGT="$( echo "$TMP" | jq -rcM ".target|strings" | grep -Eo "^[0-9.]+$" )"
    [ -z "$TAGT" ] && {
        TAGT="$REMOTE_ADDR"; MSGAPND "[ $ID ] 映射目标缺失,使用请求源地址( $TAGT )."; }
    ipcalc -c "$TAGT" || {
        MSGAPND "[ $ID ] 目标地址格式错误,已忽略."; continue; }
    
    #TTL测试
    MTTL="$( echo "$TMP" | jq -rcM ".mapttl|strings" | grep -Eo "^[0-9]+$"  )"
    [ -z "$MTTL" ] && {
        MTTL=0; [ "$MAPT" == "V4CLUT" ] && MTTL=35
        MSGAPND "[ $ID ] TTL参数缺失,使用缺省值( $MTTL )."; }
    
    #主机名称更新排斥当前同名主机和集群记录,集群名称更新仅排斥当前同名主机记录
    CDT=""; [ "$MAPT" == "V4CLUT" ] && \
    CDT="AND ( maptype==\"V4HOST\" OR target==\"$TAGT\" )"
    echo "BEGIN; DELETE FROM $TBNMMP WHERE name==\"$NAME\" $CDT;
    INSERT INTO $TBNMMP VALUES( \"$NAME\", \"$MAPT\", \"$TAGT\",
    strftime(\"%s\"), $MTTL); COMMIT;" | \
    sqlite3 -cmd ".timeout 3000" "$XCSTDB"
    
    MSGAPND "[ $ID ] 名称映射更新: $NAME => $TAGT ( $MAPT, TTL=$MTTL )."
    FLUSH="YES"; (( OPOK++ )); done; MSGAPND "请求: $OPCT, 成功: $OPOK."

#启动hosts刷新过程
[ "$FLUSH" == "YES" ] && ( exec 4<&-; setsid "$HFLUSH" & )

#返回结果

RESPONSE
exit 0
