#!/bin/sh
#
# Copyright (C) 2020 luci-app-jd-dailybonus <jerrykuku@qq.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#
# 501 下载脚本出错
# 101 没有新版本无需更新
# 0   更新成功

NAME=jd-dailybonus
REMOTE_SCRIPT=https://raw.githubusercontent.com/NobyDa/Script/master/JD-DailyBonus/JD_DailyBonus.js
TEMP_SCRIPT=/tmp/JD_DailyBonus.js
JD_SCRIPT=/usr/share/jd-dailybonus/JD_DailyBonus.js
LOG_HTM=/www/JD_DailyBonus.htm
CRON_FILE=/etc/crontabs/root
usage() {
    cat <<-EOF
		Usage: app.sh [options]

		Valid options are:

		    -c1 <cookie 1>          First JD Cookie
		    -c2 <cookie 2>          Second JD Cookie
		    -r                      Run Script
		    -u                      Update Script From Server
EOF
    exit $1
}

# Common functions

uci_get_by_name() {
    local ret=$(uci get $NAME.$1.$2 2>/dev/null)
    echo ${ret:=$3}
}

uci_get_by_type() {
    local ret=$(uci get $NAME.@$1[0].$2 2>/dev/null)
    echo ${ret:=$3}
}

cancel() {
    if [ $# -gt 0 ]; then
        echo "$1"
    fi
    exit 1
}

fill_cookie() {
    cookie1=$(uci_get_by_type global cookie)
    if [ ! "$cookie1" = "" ]; then
        varb="var Key = '$cookie1'" 
        sed -i "s/^var Key =.*/$varb/g" $JD_SCRIPT
    fi

    cookie2=$(uci_get_by_type global cookie2)
    if [ ! "$cookie2" = "" ]; then
        varb2="var DualKey = '$cookie2'" 
        sed -i "s/^var DualKey =.*/$varb2/g" $JD_SCRIPT
    fi
}

remote_ver=$(cat $TEMP_SCRIPT | sed -n '/更新时间/p' | awk '{print $NF}' | sed 's/v//')
local_ver=$(uci_get_by_type global version)


add_cron() {
	sed -i '/jd-dailybonus/d' $CRON_FILE
	[ $(uci_get_by_type global auto_run 0) -eq 1 ] && echo "5 $(uci_get_by_type global auto_run_time) * * * /usr/share/jd-dailybonus/newapp.sh -r" >> $CRON_FILE
	[ $(uci_get_by_type global auto_update 0) -eq 1 ] && echo "1 $(uci_get_by_type global auto_update_time) * * * /usr/share/jd-dailybonus/newapp.sh -u" >> $CRON_FILE
	crontab $CRON_FILE
}


# Run Script
run() {
    fill_cookie
    echo -e $(date '+%Y-%m-%d %H:%M:%S %A') >$LOG_HTM 2>/dev/null
    nohup node $JD_SCRIPT >>$LOG_HTM 2>/dev/null &
}

# Update Script From Server

check_ver(){
    wget-ssl --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t 3 -T 10 -q $REMOTE_SCRIPT -O $TEMP_SCRIPT
    if [ $? -ne 0 ]; then
        cancel "501"
    else
        echo $remote_ver
    fi
    
}

update() {
    wget-ssl --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36" --no-check-certificate -t 3 -T 10 -q $REMOTE_SCRIPT -O $TEMP_SCRIPT
    if [ $? -ne 0 ]; then
        cancel "501"
    fi
    if [ $(echo "$local_ver < $remote_ver" | bc) -eq 1 ]; then
        cp -r $TEMP_SCRIPT $JD_SCRIPT
        fill_cookie
        uci set jd-dailybonus.@global[0].version=$remote_ver
        uci commit jd-dailybonus
        cancel "0"
    else
        cancel "101"
    fi
}

while getopts ":anruh" arg; do
    case "$arg" in
    a)
        add_cron
        exit 0
        ;;
    n)
        check_ver
        exit 0
        ;;
    r)
        run
        exit 0
        ;;
    u)
        update
        exit 0
        ;;
    h)
        usage 0
        ;;
    esac
done
