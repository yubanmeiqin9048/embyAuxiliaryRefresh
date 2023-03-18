#!/bin/bash
parement=$1
initpath=${parement/'/Onedrive'/}                       #删除传入路径的多余信息
filename=${initpath##*/}                                #获取文件名
alistTarget="/share1${initpath%/*}"                     #拼接为alist对应的网盘目录
embyTarget="/mnt/share1${initpath/'/Video'/}"           #拼接为emby的媒体库目录
rcloneTarget="${initpath%/*}"
log_dir="<your dir>"
embyUrl="localhost:9187/emby/Library/Media/Updated"
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
    while :
    do
        respond=$(rclone rc vfs/refresh dir="${rcloneTarget}")
        isexist=$(echo -e ${respond} | grep -P -o -w "OK")
        if [[ -n ${isexist} ]]
        then
            break
        else
            sleep 7s
        fi
    done
    echo -e "${time}: ${respond}" | tr -d '\t\n' >> ${log_dir}/rclone.log
    echo "" >> ${log_dir}/rclone.log
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
        code=$(echo ${respond} | sed 's/,/\n/g' | grep "code" | sed 's/:/\n/g' | sed '1d' | sed 's/}//g')
        message=$(echo ${respond} | sed 's/,/\n/g' | grep "message" | sed 's/:/\n/g' | sed '1d' | sed 's/"//g')
        isexist=$(echo -e ${respond} | grep -P -o -w "${filename}")
        echo -e "${time} code: ${code}" >> ${log_dir}/webhook.log
        echo -e "${time} message: ${message}" >> ${log_dir}/webhook.log
	echo -e "${time} isexist: ${isexist}"  >> ${log_dir}/webhook.log
        if [[ "$code" == "200" && -n ${isexist} ]]
        then
            break
        else
            echo "${respond}"
            sleep 7s
        fi
    done
    echo -e "time: ${time}" >> ${log_dir}/work.log
    echo -e "path: ${initpath}\n\n" >> ${log_dir}/work.log
    sleep 3s
    rcloneVfsRefresh
}
fetchAlistPathApi
