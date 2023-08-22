#!/bin/bash
target_path=$1
size=$2
task_path="/path/webhook/temp"
if [[ "target_path" == *"SerializedAnime"* ]]; then
    echo -e "${target_path/'/Video'/'/share2/Video'}*${size}" | tr -d '\n' > "$task_path/$size"
else
    echo -e "${target_path/'/Video'/'/share1/Video'}*${size}" | tr -d '\n' > "$task_path/$size"
fi