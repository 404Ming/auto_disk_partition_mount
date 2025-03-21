# Auto Disk Partition Mount Script

[English](README.md) | [中文](README_CN.md)

A Shell script for automatically detecting, partitioning, formatting, and mounting disks. The script is available in both English and Chinese versions.

## Features

- Automatic disk partition detection
- Automatic partition creation and expansion
- Automatic partition formatting to ext4 filesystem
- Automatic partition mounting to /mnt directory
- Support for failure retry mechanism (up to 3 times)
- Detailed logging
- Colored output support
- Excludes system critical disks (/dev/vda*, /dev/sda*, /dev/loop*)

## Files

- `auto_disk_partition_mount.sh`: English version script
- `auto_disk_partition_mount_cn.sh`: Chinese version script

## System Requirements

- Linux operating system
- root privileges
- Required commands:
  - fdisk
  - partprobe
  - mkfs.ext4
  - mount
  - umount
  - blkid
  - lsblk
  - resize2fs

## Usage

1. Ensure the script has execution permissions:
```bash
chmod +x auto_disk_partition_mount.sh
# or
chmod +x auto_disk_partition_mount_cn.sh
```

2. Run the script with root privileges:
```bash
sudo ./auto_disk_partition_mount.sh
# or
sudo ./auto_disk_partition_mount_cn.sh
```


## Workflow

1. Check root privileges
2. Scan block devices in the system
3. Exclude system critical disks
4. For each available disk:
   - Check if partitioned
   - Create partition if not partitioned
   - Check if partition uses all disk space
   - Expand partition if not using all space
   - Check if partition is formatted
   - Format to ext4 if not formatted
   - Mount partition to /mnt directory
   - Retry up to 3 times if mounting fails

## Security Notes

- Script excludes system critical disks (/dev/vda*, /dev/sda*, /dev/loop*)
- Backup important data before running the script
- Script requires root privileges
- Cleans up temporary files and mount points on failure

## Important Notes

- Understand the script's functionality before running
- Test in a test environment first
- Script modifies disk partition tables, use with caution
- Ensure sufficient disk space is available

## Error Handling

- Script includes comprehensive error handling
- Automatically retries on mount failure (up to 3 times)
- Cleans up previous operations before each retry
- Skips disk after 3 failed retries

## Contributing

Issues and improvement suggestions are welcome. To contribute code:

1. Fork this repository
2. Create your feature branch
3. Commit your changes
4. Push to your branch
5. Create a Pull Request

## License

MIT License
