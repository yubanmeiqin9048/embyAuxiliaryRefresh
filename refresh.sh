#!/bin/bash
parement=$1
file="${parement/'/Video'/}"
alistTarget="/share1${file%/*}"
embyTarget="/mnt/share1${file}"
rcloneTarget="${file%/*}"
# echo -e "\n"
# echo "$alistTarget"
# echo "$embyTarget"
# echo "$rcloneTarget"
log_dir="<your dir>"
embyUrl="localhost:9187/emby/Library/Media/Updated/"
embyToken="<your token>"
alistUrl="localhost:6355/api/fs/list"
alistToken="<your token>"

function fetchEmbyApi(){
    sleep 5s
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
    sleep 68s
    body="{\"path\": \"${alistTarget}\", \"refresh\": true}"
    while :
    do
        respond=$(curl -X POST \
        ${alistUrl} \
        -H "Authorization:${alistToken}" \
        -H "Content-Type:application/json;charset=utf-8" \
        -d "${body}")
        wait
        code=$(echo $respond | sed 's/,/\n/g' | grep "code" | sed 's/:/\n/g' | sed '1d' | sed 's/}//g')
        message=$(echo $respond | sed 's/,/\n/g' | grep "message" | sed 's/:/\n/g' | sed '1d' | sed 's/"//g')
        time=`date +'%Y-%m-%d %H:%M:%S'`
        if [[ "$code" == "200" ]]
        then
            echo "$respond"
            break
        else
            sleep 5s
        fi
    done
    echo -e "time: ${time}" >> ${log_dir}/work.log
    echo -e "code: ${code}" >> ${log_dir}/work.log
    echo -e "message: ${message}" >> ${log_dir}/work.log
    echo -e "path: ${file}\n\n" >> ${log_dir}/work.log
    sleep 5s
    rcloneVfsRefresh
}
fetchAlistPathApi
