#!/bin/bash

# 设置监听路径
inotify_path="/path/webhook/temp" 
# 设置工作目录
work_path="/path/webhook"
# 设置线程数
max_thread=2

# 初始化消息队列和线程计数器
message_queue=$work_path/pipe
process_queue=$(mktemp --dry-run)
if [ ! -p "$message_queue" ]; then mkfifo "${message_queue}"; fi
if [ ! -p "$work_path/log/fail.txt" ]; then touch "$work_path/log/fail.txt"; fi
mkfifo $process_queue
exec 99<>${message_queue}
exec 33<>${process_queue}
rm -f $process_queue
echo 0 >&33

# 函数用于处理中断信号
function on_interrupt() {
    pkill inotifywait  # 发送终止信号给inotifywait进程
    exit 0
}

# 设置中断信号处理函数
trap on_interrupt SIGINT

# 计数器
function counter() {
    local triger=$1
    local count
    local processed_count
    flock 33
    read -u 33 count
    if [[ "$triger" = "up" ]]; then
        processed_count=$((count + 1))
    else
        processed_count=$((count - 1))
    fi
    echo $processed_count >&33
    flock -u 33
    return $processed_count
}

# 将事件写入消息队列
function producer() {
    local data="$1"
    echo "$data" >&99
}

# 处理单个事件
function executor() {
    local processed_count
    bash "$work_path/run.sh" -a "$1*1"
    counter "down"; processed_count=$?
}

# 监听消息队列
function main() {
    local processed_count
    while true; do
        flock 33
        read -u 33 processed_count
        echo $processed_count >&33
        flock -u 33
        while [ $processed_count -lt $max_thread ]; do
            local event
            # 读取消息队列
            read -u 99 event
            counter "up"; processed_count=$?
            executor "$event" &
        done
        sleep 7
    done
}

inotifywait -m "$inotify_path" -e create --format "%w%f"  |
while read -r FILE; do
    # 延迟一秒
    sleep 1
    # 读取webhook数据
    msg=$(cat "$FILE")
    # 将数据发送到消息队列
    producer "$msg" &
    # 删除临时文件
    rm -f $FILE
    # 将数据写入task.txt
    echo -e "$msg" >> "$work_path/log/task.txt"
done &

main