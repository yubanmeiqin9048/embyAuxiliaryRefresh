#!/bin/bash
task_path='/path/webhook/temp'
in_path=$2
resource_category=$3
resource_subcategory=$4
path_change='/TV/Anime'
webflag_list=("web" "\[sakurato\]")
remote_dest='/share1'
# 使用sed删除首尾的方括号并替换中间的双引号和逗号为'\n'，这将使每个元素占据一行
target_path_str=$(echo "$1" | sed 's/^\[\|\]$//g' | sed 's/","/\n/g' | sed 's/"//g')

mapfile -t target_path_list <<< "$target_path_str"

#echo -e "$in_path" > "/home/zhang/webhook/test"

if [[ "$resource_category" == "电视剧" ]] && [[ "$resource_subcategory" == "Anime" ]]; then
    for webflag in "${webflag_list[@]}"; do
        echo -e "come for"
        echo "webflag: ${webflag}"
        if [[ "${in_path,,}" == *$webflag* ]]; then
            path_change='/TV/SerializedAnime'
            remote_dest='/share2'
            break
        fi
    done
fi

for target_path in "${target_path_list[@]}"; do
    size=$(stat -c %s "$target_path")
    echo -e "${target_path/'/Video'/"${remote_dest}/Video"}*${path_change}*${size}" | tr -d '\n' > "$task_path/$(date +%Y%m%d%H%M%S)_$RANDOM"
done