#!/bin/bash

# 脚本功能：
# 1. 自动检测磁盘是否已分区，未分区则创建分区
# 2. 检测分区是否已格式化，未格式化则格式化为ext4
# 3. 自动挂载分区到/mnt目录
# 4. 排除/dev/vda*, /dev/sda*, /dev/loop*设备
# 5. 包含失败重试机制（最多重试3次）

# 日志文件路径
LOG_FILE="/var/log/auto_disk_partition_mount.log"

# 日志级别
LOG_LEVEL_INFO="信息"
LOG_LEVEL_WARN="警告"
LOG_LEVEL_ERROR="错误"
LOG_LEVEL_SUCCESS="成功"

# 最大重试次数
MAX_RETRIES=3

# 日志记录函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 构建日志消息
    local log_message="[${timestamp}] [${level}] ${message}"
    
    # 输出到控制台
    case "$level" in
        "$LOG_LEVEL_ERROR")
            echo -e "\e[31m${log_message}\e[0m" ;;  # 红色
        "$LOG_LEVEL_WARN")
            echo -e "\e[33m${log_message}\e[0m" ;;  # 黄色
        "$LOG_LEVEL_SUCCESS")
            echo -e "\e[32m${log_message}\e[0m" ;;  # 绿色
        *)
            echo -e "${log_message}" ;;  # 默认颜色
    esac
    
    # 输出到日志文件
    echo "${log_message}" >> "$LOG_FILE"
}

# 检查设备是否为排除设备
is_excluded_device() {
    local disk="$1"
    [[ $disk == /dev/vda* || $disk == /dev/sda* || $disk == /dev/loop* || $disk == /dev/sr* ]]
    return $?
}

# 检查是否是整个磁盘而非分区
is_whole_disk() {
    local disk="$1"
    [[ ! $disk =~ [0-9]$ ]]
    return $?
}

# 创建分区
create_partition() {
    local disk="$1"
    log "$LOG_LEVEL_INFO" "磁盘 $disk 未分区，正在创建分区..."
    
    # 创建一个完整磁盘的主分区
    echo -e "n\np\n1\n\n\nw" | fdisk $disk
    
    # 刷新内核分区表
    partprobe $disk
    sleep 5
    
    log "$LOG_LEVEL_SUCCESS" "已创建分区 ${disk}1"
    echo "${disk}1"
}

# 扩展分区到全部磁盘空间
expand_partition() {
    local disk="$1"
    local partition="$2"
    local mount_point=""
    
    # 获取磁盘和分区大小（以扇区为单位）
    local total_sectors=$(fdisk -l $disk | grep "^Disk $disk" | awk '{print $7}')
    
    # 获取分区结束扇区
    local end_sector=$(fdisk -l $disk | grep "^$partition" | awk '{print $3}')
    
    # 去除结尾的逗号（如有）
    end_sector=${end_sector%,}
    
    # 检查是否有足够的未分配空间
    if [ $((total_sectors - end_sector)) -le 10 ]; then
        log "$LOG_LEVEL_INFO" "分区 $partition 已使用全部可用磁盘空间"
        return 0
    fi
    
    log "$LOG_LEVEL_INFO" "分区 $partition 未使用全部磁盘空间，正在扩展..."
    
    # 记录分区的起始位置
    local start_sector=$(fdisk -l $disk | grep "^$partition" | awk '{print $2}')
    
    # 检查分区是否已挂载，如果挂载则先卸载
    if grep -q "$partition " /proc/mounts; then
        mount_point=$(grep "$partition " /proc/mounts | awk '{print $2}')
        log "$LOG_LEVEL_WARN" "临时卸载 $partition 以进行分区调整"
        umount $partition
    fi
    
    # 删除并重新创建分区
    fdisk $disk << EOF
d
1
n
p
1
$start_sector

w
EOF
    # 刷新分区表
    partprobe $disk
    sleep 5
    
    # 重新挂载分区（如果之前已挂载）
    if [ ! -z "$mount_point" ]; then
        mount $partition $mount_point
        log "$LOG_LEVEL_SUCCESS" "重新挂载 $partition 到 $mount_point"
    fi
    
    # 检查分区上的文件系统并扩展
    if blkid $partition | grep -q "TYPE=\"ext"; then
        log "$LOG_LEVEL_INFO" "调整ext文件系统大小以使用全部可用空间..."
        resize2fs $partition
        log "$LOG_LEVEL_SUCCESS" "文件系统已扩展"
    fi
    
    return 0
}

# 格式化分区
format_partition() {
    local partition="$1"
    
    # 检查分区是否已格式化
    if blkid $partition | grep -q "TYPE="; then
        log "$LOG_LEVEL_INFO" "$partition 已格式化"
        return 0
    fi
    
    log "$LOG_LEVEL_INFO" "$partition 未格式化，正在格式化为ext4..."
    mkfs.ext4 -F $partition
    sleep 5
    log "$LOG_LEVEL_SUCCESS" "$partition 已格式化为ext4"
    return 0
}

# 挂载分区
mount_partition() {
    local partition="$1"
    local mount_point="/mnt/$(basename $partition)"
    
    # 检查分区是否已挂载
    if grep -q "$partition " /proc/mounts; then
        log "$LOG_LEVEL_INFO" "$partition 已经挂载，跳过"
        return 0
    fi
    
    # 创建挂载点目录
    mkdir -p $mount_point
    
    # 尝试挂载分区
    if mount $partition $mount_point; then
        log "$LOG_LEVEL_SUCCESS" "成功挂载 $partition 到 $mount_point"
        return 0
    else
        log "$LOG_LEVEL_ERROR" "挂载 $partition 到 $mount_point 失败"
        return 1
    fi
}

# 处理单个磁盘的函数（包含重试机制）
process_disk() {
    local disk=$1
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        if [ $retry_count -gt 0 ]; then
            log "$LOG_LEVEL_WARN" "磁盘 $disk 第 $retry_count 次重试（共 $MAX_RETRIES 次）"
        fi
        
        log "$LOG_LEVEL_INFO" "正在处理磁盘: $disk"
        
        # 检查磁盘是否已分区
        if fdisk -l $disk | grep -q "${disk}[0-9]"; then
            log "$LOG_LEVEL_INFO" "$disk 已有分区"
            # 获取第一个分区
            partition=$(lsblk -lnpo NAME $disk | grep "${disk}[0-9]" | head -n1)
            log "$LOG_LEVEL_INFO" "使用分区: $partition"
            
            # 扩展分区到全部磁盘空间
            expand_partition "$disk" "$partition"
        else
            # 创建分区
            partition=$(create_partition "$disk")
        fi
        
        # 格式化分区
        format_partition "$partition"
        
        # 挂载分区
        if mount_partition "$partition"; then
            success=true
            log "$LOG_LEVEL_SUCCESS" "成功处理磁盘 $disk"
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log "$LOG_LEVEL_WARN" "正在卸载并清理，准备重试..."
                umount -f "/mnt/$(basename $partition)" 2>/dev/null
                rm -rf "/mnt/$(basename $partition)"
                sleep 5
            else
                log "$LOG_LEVEL_ERROR" "磁盘 $disk 处理失败，已重试 $MAX_RETRIES 次，跳过..."
            fi
        fi
    done
}

# 主函数
main() {
    # 确保脚本以root权限运行
    if [ "$(id -u)" -ne 0 ]; then
        log "$LOG_LEVEL_ERROR" "此脚本需要root权限运行"
        exit 1
    fi
    
    # 寻找所有块设备
    log "$LOG_LEVEL_INFO" "正在查找可挂载的磁盘设备..."
    
    # 获取所有块设备列表
    local disk_list=$(lsblk -dpno NAME | grep "^/dev/")
    
    for disk in $disk_list; do
        # 排除指定设备和非整个磁盘设备
        if is_excluded_device "$disk" || ! is_whole_disk "$disk"; then
            [ -n "$disk" ] && log "$LOG_LEVEL_INFO" "跳过设备: $disk"
            continue
        fi
        
        process_disk "$disk"
    done
    
    log "$LOG_LEVEL_SUCCESS" "磁盘挂载操作完成"
}

# 执行主函数
main 