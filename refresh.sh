#!/bin/bash
parement=$1
initpath=${parement/'：'/‛：}			#处理特殊字符
filename=$(basename "${initpath}")		  #取文件名
parentpath=$(dirname "${initpath}")		  #取父目录	
alistTarget="/share1${parentpath}"		  #拼接alist刷新路径
embyTarget="/mnt/share1${initpath/'/Video'/}"	  #拼接emby刷新路径
rcloneTarget="${parentpath}"			  #rclone缓存刷新路径
log_dir="<your dir>"				  #日志地址
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
    echo -e "${time}: ${respond}" | tr -d '\t\n' >> ${log_dir}/debug.log
    echo "" >> ${log_dir}/debug.log
    fetchEmbyApi
}

function refreshAlistPathApi(){
  body="{\"path\": \"${1}\", \"refresh\": true}"
  respond=$(curl -X POST \
      ${alistUrl} \
      -H "Authorization:${alistToken}" \
      -H "Content-Type:application/json;charset=utf-8" \
      -d "${body}")
  echo ${respond}
}

function main(){
    while :
    do
      respond=$(refreshAlistPathApi "${alistTarget}")
      code=$(echo ${respond} | sed 's/,/\n/g' | grep "code" | sed 's/:/\n/g' | sed '1d' | sed 's/}//g')
      message=$(echo ${respond} | sed 's/,/\n/g' | grep "message" | sed 's/:/\n/g' | sed '1d' | sed 's/"//g')
      isexist=$(echo -e ${respond} | grep -P -o -w "${filename}")
      echo -e "${time} code: ${code}" >> ${log_dir}/debug.log
      echo -e "${time} message: ${message}" | tr -d '\n' >> ${log_dir}/debug.log
      echo -e "${time} isexist: ${isexist}"  >> ${log_dir}/debug.log
      echo -e "${time} initpath: ${initpath}"  >> ${log_dir}/debug.log
      if [[ "$code" == "200" && -n ${isexist} ]]
      then
        break
      elif [[ "$code" == "500" ]]
      then
        alistTarget_parent=$(dirname "${alistTarget}")
        refreshAlistPathApi "${alistTarget_parent}"
        break
      else
        echo -e "${time} respond: ${respond}" >> ${log_dir}/debug.log
        sleep 7s
      fi
    done
    echo -e "time: ${time}" >> ${log_dir}/info.log
    echo -e "path: ${initpath}\n\n" >> ${log_dir}/info.log
    sleep 3s
    rcloneVfsRefresh
}

main
