#!/bin/bash

# Script to check if disk is partitioned, if not then partition it,
# check if partition is formatted, if not then format as ext4, and mount it
# Exclude /dev/vda*, /dev/sda*, /dev/loop* devices

# Log file path
LOG_FILE="/var/log/auto_disk_partition_mount.log"

# Log levels
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_WARN="WARNING"
LOG_LEVEL_ERROR="ERROR"
LOG_LEVEL_SUCCESS="SUCCESS"

# Maximum retry attempts
MAX_RETRIES=3

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Build log message
    local log_message="[${timestamp}] [${level}] ${message}"
    
    # Output to console
    case "$level" in
        "$LOG_LEVEL_ERROR")
            echo -e "\e[31m${log_message}\e[0m" ;;  # Red
        "$LOG_LEVEL_WARN")
            echo -e "\e[33m${log_message}\e[0m" ;;  # Yellow
        "$LOG_LEVEL_SUCCESS")
            echo -e "\e[32m${log_message}\e[0m" ;;  # Green
        *)
            echo -e "${log_message}" ;;  # Default color
    esac
    
    # Output to log file
    echo "${log_message}" >> "$LOG_FILE"
}

# Check if device is excluded
is_excluded_device() {
    local disk="$1"
    [[ $disk == /dev/vda* || $disk == /dev/sda* || $disk == /dev/loop* || $disk == /dev/sr* ]]
    return $?
}

# Check if it's a whole disk rather than a partition
is_whole_disk() {
    local disk="$1"
    [[ ! $disk =~ [0-9]$ ]]
    return $?
}

# Create partition
create_partition() {
    local disk="$1"
    log "$LOG_LEVEL_INFO" "$disk is not partitioned, creating partition..."
    
    # Create a primary partition using the entire disk
    echo -e "n\np\n1\n\n\nw" | fdisk $disk
    
    # Refresh kernel partition table
    partprobe $disk
    sleep 5
    
    log "$LOG_LEVEL_SUCCESS" "Created partition ${disk}1"
    echo "${disk}1"
}

# Expand partition to use all disk space
expand_partition() {
    local disk="$1"
    local partition="$2"
    local mount_point=""
    
    # Get disk and partition size (in sectors)
    local total_sectors=$(fdisk -l $disk | grep "^Disk $disk" | awk '{print $7}')
    
    # Get partition end sector
    local end_sector=$(fdisk -l $disk | grep "^$partition" | awk '{print $3}')
    
    # Remove trailing comma if present
    end_sector=${end_sector%,}
    
    # Check if there's enough unallocated space
    if [ $((total_sectors - end_sector)) -le 10 ]; then
        log "$LOG_LEVEL_INFO" "Partition $partition already uses all available disk space"
        return 0
    fi
    
    log "$LOG_LEVEL_INFO" "Partition $partition does not use all disk space, expanding..."
    
    # Record partition start position
    local start_sector=$(fdisk -l $disk | grep "^$partition" | awk '{print $2}')
    
    # Check if partition is mounted, unmount if it is
    if grep -q "$partition " /proc/mounts; then
        mount_point=$(grep "$partition " /proc/mounts | awk '{print $2}')
        log "$LOG_LEVEL_WARN" "Temporarily unmounting $partition for partition adjustment"
        umount $partition
    fi
    
    # Delete and recreate partition
    fdisk $disk << EOF
d
1
n
p
1
$start_sector

w
EOF
    # Refresh partition table
    partprobe $disk
    sleep 5
    
    # Remount partition if it was previously mounted
    if [ ! -z "$mount_point" ]; then
        mount $partition $mount_point
        log "$LOG_LEVEL_SUCCESS" "Remounted $partition to $mount_point"
    fi
    
    # Check and expand filesystem if it's ext
    if blkid $partition | grep -q "TYPE=\"ext"; then
        log "$LOG_LEVEL_INFO" "Resizing ext filesystem to use all available space..."
        resize2fs $partition
        log "$LOG_LEVEL_SUCCESS" "Filesystem expanded"
    fi
    
    return 0
}

# Format partition
format_partition() {
    local partition="$1"
    
    # Check if partition is already formatted
    if blkid $partition | grep -q "TYPE="; then
        log "$LOG_LEVEL_INFO" "$partition is already formatted"
        return 0
    fi
    
    log "$LOG_LEVEL_INFO" "$partition is not formatted, formatting as ext4..."
    mkfs.ext4 -F $partition
    sleep 5
    log "$LOG_LEVEL_SUCCESS" "$partition has been formatted as ext4"
    return 0
}

# Mount partition
mount_partition() {
    local partition="$1"
    local mount_point="/mnt/$(basename $partition)"
    
    # Check if partition is already mounted
    if grep -q "$partition " /proc/mounts; then
        log "$LOG_LEVEL_INFO" "$partition is already mounted, skipping"
        return 0
    fi
    
    # Create mount point directory
    mkdir -p $mount_point
    
    # Attempt to mount partition
    if mount $partition $mount_point; then
        log "$LOG_LEVEL_SUCCESS" "Successfully mounted $partition to $mount_point"
        return 0
    else
        log "$LOG_LEVEL_ERROR" "Failed to mount $partition to $mount_point"
        return 1
    fi
}

# Process single disk function with retry mechanism
process_disk() {
    local disk=$1
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = false ]; do
        if [ $retry_count -gt 0 ]; then
            log "$LOG_LEVEL_WARN" "Retry attempt $retry_count of $MAX_RETRIES for disk $disk"
        fi
        
        log "$LOG_LEVEL_INFO" "Processing disk: $disk"
        
        # Check if disk is already partitioned
        if fdisk -l $disk | grep -q "${disk}[0-9]"; then
            log "$LOG_LEVEL_INFO" "$disk already has partitions"
            # Get first partition
            partition=$(lsblk -lnpo NAME $disk | grep "${disk}[0-9]" | head -n1)
            log "$LOG_LEVEL_INFO" "Using partition: $partition"
            
            # Expand partition to use all disk space
            expand_partition "$disk" "$partition"
        else
            # Create partition
            partition=$(create_partition "$disk")
        fi
        
        # Format partition
        format_partition "$partition"
        
        # Mount partition
        if mount_partition "$partition"; then
            success=true
            log "$LOG_LEVEL_SUCCESS" "Successfully processed disk $disk"
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log "$LOG_LEVEL_WARN" "Unmounting and cleaning up before retry..."
                umount -f "/mnt/$(basename $partition)" 2>/dev/null
                rm -rf "/mnt/$(basename $partition)"
                sleep 5
            else
                log "$LOG_LEVEL_ERROR" "Failed to process disk $disk after $MAX_RETRIES attempts, skipping..."
            fi
        fi
    done
}

# Main function
main() {
    # Ensure script runs with root privileges
    if [ "$(id -u)" -ne 0 ]; then
        log "$LOG_LEVEL_ERROR" "This script requires root privileges"
        exit 1
    fi
    
    # Find all block devices
    log "$LOG_LEVEL_INFO" "Searching for mountable disk devices..."
    
    # Get list of all block devices
    local disk_list=$(lsblk -dpno NAME | grep "^/dev/")
    
    for disk in $disk_list; do
        # Skip excluded devices and non-whole disk devices
        if is_excluded_device "$disk" || ! is_whole_disk "$disk"; then
            [ -n "$disk" ] && log "$LOG_LEVEL_INFO" "Skipping device: $disk"
            continue
        fi
        
        process_disk "$disk"
    done
    
    log "$LOG_LEVEL_SUCCESS" "Mount operation completed"
}

# Execute main function
main 