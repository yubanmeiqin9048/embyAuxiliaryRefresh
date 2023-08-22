declare -a rclone_command
declare -a remote_storage_init=("139&ali" "onedrive")
declare -a remote_storage_process
log_dir="/path/webhook/log"
emby_media_path="/mnt/share1"
nastool_map_path="/path/disk/alistmap"
emby_url="localhost:8096"
emby_token=""
log_dir="/path/webhook/log"
alist_url="localhost:5244"
alist_token=""

function formatCommand() {
    local target_path="${in_path//$nastool_map_path/}"
    if [ "$(echo "$size > 20" | bc -l)" -eq 1 ]; then
        remote_dest="/share2"
    fi
    for ((i=0; i<${#remote_storage_process[@]}; i++)); do
        if [[ "${remote_storage_process[i]}" == "${remote_storage_init[0]}" ]]; then
            rclone_command[i]="rclone copyto -v --config=/home/zhang/rclone/rclone.conf --include \"{$filename}.*\" \"${in_path}\" \"NASTOOL:${remote_dest}${target_path/'/TV/Anime'/${fields[1]}}\" --log-file=\"/tmp/${fields[2]}.${remote_storage_process[i]}\" --ignore-existing"
        else
            rclone_command[i]="rclone copyto -v --config=/home/zhang/rclone/rclone.conf --include \"{$filename}.*\" \"${in_path}\" \"backup:${target_path/'/TV/Anime'/${fields[1]}}\" --log-file=\"/tmp/${fields[2]}.${remote_storage_process[i]}\" --ignore-existing"
        fi
    done
}

function rcloneUpload() {
    local fail_count=()
    for ((i=0; i<${#rclone_command[@]}; i++)); do
        {
            eval "${rclone_command[i]}"
        } &
    done
    wait
    for ((i=0; i<${#rclone_command[@]}; i++)); do
        if ! grep -qFo "${file}: Copied (new)" "/tmp/${fields[2]}.${remote_storage_process[i]}"; then
            retry_flag=1
            fail_count+=("${remote_storage_process[i]}")
        fi
    done
    if [[ ${#fail_count[@]} -eq ${#remote_storage_init[@]} ]]; then
        refresh_flag=1
        return 1
    elif [[ "${fail_count[0]}" == "${remote_storage_init[1]}" ]]; then
        refresh_flag=1
        return 2
    elif [[ "${fail_count[0]}" == "${remote_storage_init[0]}" ]]; then
        return 3
    else
        return 0
    fi
}

function fetchAlistRefreshPathApi() {
    local target_path=$1
    local target_path="${target_path//$nastool_map_path/'/share4'}"
    local body="{\"path\": \"${target_path/'/TV/Anime'/${fields[1]}}\", \"refresh\": true}"
    local respond=$(curl -X POST \
                ${alist_url}/api/fs/list \
                -H "Authorization:${alist_token}" \
                -H "Content-Type:application/json;charset=utf-8" \
                -d "${body}")
    local code=$(echo ${respond} | sed 's/,/\n/g' | grep "code" | sed 's/:/\n/g' | sed '1d' | sed 's/}//g')
    sleep 3
    if [[ "$code" == "500" ]]; then
        fetchAlistRefreshPathApi "$(dirname "$target_path")"
    fi
}

function rcloneVfsRefresh() {
    local target_path="${in_path//$nastool_map_path/}"
    docker exec -it rclone sh -c "rclone vfs/refresh dir=${target_path/'/TV/Anime'/${fields[1]}}"
}

function fetchEmbyRefreshMediaApi() {
    local target_path="${in_path//$nastool_map_path/$emby_media_path}"
    target_path="${target_path//'/Video'/}"
    local body="{\"Updates\":[{\"path\":\"${target_path/'/TV/Anime'/${fields[1]}}\",\"updateType\":\"Created\"}]}"
    curl -X POST \
    ${emby_url}/emby/Library/Media/Updated?api_key=${emby_token} \
    -H "Content-Type:application/json;charset=utf-8" \
    -d "${body}"
}

function deleteLinkFile() {
    find "$in_path" -type f -name "*${filename}*" -delete
}

function log() {
    sed -i "/$(sed 's/[^^]/[&]/g; s/\^/\\^/g; $!a\'$'\n''\\n' <<< "${fields[0]/nastool_map_path/"${nastool_map_path}/${remote_dest}"}*${fields[1]}*${fields[2]}*${fields[3]}")/d" "$log_dir/fail.txt"
    if [[ $status_code -eq 0 ]]; then
        echo -e "${fields[0]/nastool_map_path/"${nastool_map_path}/${remote_dest}"}*${fields[1]}*${fields[2]}" >> "$log_dir/finish.txt"
    else
        echo -e "${fields[0]/nastool_map_path/"${nastool_map_path}/${remote_dest}"}*${fields[1]}*${fields[2]}*$status_code" >> "$log_dir/fail.txt"
    fi
}

function wholeProcess() {
    formatCommand
    rcloneUpload; status_code=$?
    if [[ $refresh_flag -eq 0 ]]; then
        fetchAlistRefreshPathApi "$in_path"
        #rcloneVfsRefresh
        fetchEmbyRefreshMediaApi
        if [[ $retry_flag -eq 0 ]]; then deleteLinkFile; fi
    fi
    log
}

function onlyUpload() {
    formatCommand
    rcloneUpload; status_code=$?
    if [[ $retry_flag -eq 0 ]]; then deleteLinkFile; fi
    log
}

function process() {
    in_path=$(dirname "${fields[0]}" | sed "s/\/share[0-9]//")
    file=$(basename "${fields[0]}")
    filename="${file%.*}"
    remote_dest=$(echo "${fields[0]}" | awk -F"/" '{print FS $6}')
    size=$(echo "${fields[2]} / 1073741824" | bc -l)
    echo -e "in_path=${in_path}\nremote=${remote_dest}"
    refresh_flag=0
    retry_flag=0
    case ${fields[3]} in
    1)
        remote_storage_process=("${remote_storage_init[@]}")
        wholeProcess
    ;;
    2)
        remote_storage_process=("${remote_storage_init[1]}")
        wholeProcess
    ;;
    3)
        remote_storage_process=("${remote_storage_init[0]}")
        onlyUpload
    ;;
    esac
}

function startSwith() {
    case $1 in
    -a)
        IFS="*" read -ra fields <<< "$2"
        process
    ;;
    -r)
        mapfile -t retry_task < "$log_dir/fail.txt"
        for field in "${retry_task[@]}"; do
            IFS="*" read -ra fields <<< "$field"
                process
        done
    ;;
    esac
}

main() {
    [ -z "$1" ] && return
    if [[ $1 =~ ^- ]]; then startSwith "$@"; fi
}

main "$@"
