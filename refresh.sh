#!/bin/bash
parement=$1
initpath="${parement/'/Video'/}"
filename=${parement##*/}
alistTarget="/share1${initpath%/*}"
embyTarget="/mnt/share1${initpath}"
rcloneTarget="${initpath%/*}"
log_dir="<your dir>"
embyUrl="localhost:9187/emby/Library/Media/Updated/"
embyToken="<your token>"
alistUrl="localhost:6355/api/fs/list"
alistToken="<your token>"

function fetchEmbyApi(){
    sleep 3s
    body="{\"Updates\":[{\"path\":\"${embyTarget}\",\"updateType\":\"Created\"}]}"
    $(curl -X POST \
        "${embyUrl}?api_key=${embyToken}" \
        -H "Content-Type:application/json;charset=utf-8" \
        -d "${body}")
}

function rcloneVfsRefresh(){
    echo $(rclone rc vfs/refresh dir="${rcloneTarget}") >> ${log_dir}/rclone.log
    wait
    fetchEmbyApi
}

function fetchAlistPathApi(){
    body="{\"path\": \"${alistTarget}\", \"refresh\": true}"
    while :
    do
        respond=$(curl -X POST \
        ${alistUrl} \
        -H "Authorization:${alistToken}" \
        -H "Content-Type:application/json;charset=utf-8" \
        -d "${body}")
        wait
        code=$(echo ${respond} | sed 's/,/\n/g' | grep "code" | sed 's/:/\n/g' | sed '1d' | sed 's/}//g')
        message=$(echo ${respond} | sed 's/,/\n/g' | grep "message" | sed 's/:/\n/g' | sed '1d' | sed 's/"//g')
        isexist=$(echo ${respond} | grep -o -w ${filename})
        time=`date +'%Y-%m-%d %H:%M:%S'`
        if [[ "$code" == "200" && -n ${isexist} ]]
        then
            echo "$respond"
            break
        else
            sleep 7s
        fi
    done
    echo -e "time: ${time}" >> ${log_dir}/work.log
    echo -e "code: ${code}" >> ${log_dir}/work.log
    echo -e "message: ${message}" >> ${log_dir}/work.log
    echo -e "path: ${initpath}\n\n" >> ${log_dir}/work.log
    sleep 3s
    rcloneVfsRefresh
}
fetchAlistPathApi
