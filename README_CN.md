# Auto Disk Partition Mount Script

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

## Setting up Auto-start

### Method 1: Using systemd service (Recommended)

1. Create service file:
```bash
sudo nano /etc/systemd/system/auto-disk-mount.service
```

2. Add the following content:
```ini
[Unit]
Description=Auto Disk Partition and Mount Service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/path/to/auto_disk_partition_mount.sh
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

3. Reload systemd configuration:
```bash
sudo systemctl daemon-reload
```

4. Enable the service:
```bash
sudo systemctl enable auto-disk-mount.service
```

5. Start the service:
```bash
sudo systemctl start auto-disk-mount.service
```

6. Check service status:
```bash
sudo systemctl status auto-disk-mount.service
```

### Method 2: Using rc.local (For systems using systemd)

1. Edit rc.local file:
```bash
sudo nano /etc/rc.local
```

2. Add before exit 0:
```bash
/path/to/auto_disk_partition_mount.sh
```

3. Ensure rc.local service is enabled:
```bash
sudo systemctl enable rc-local.service
```

### Method 3: Using crontab

1. Edit root's crontab:
```bash
sudo crontab -e
```

2. Add the following line:
```
@reboot /path/to/auto_disk_partition_mount.sh
```

Note:
- Replace `/path/to/auto_disk_partition_mount.sh` with the actual script path
- Method 1 (systemd service) is recommended as it's the most modern approach
- Ensure the script has execution permissions
- Test the script manually before setting up auto-start

## Logging

- Log file location: `/var/log/auto_disk_partition_mount.log`
- Logs include timestamps and log levels
- Console output supports color coding:
  - Error messages: Red
  - Warning messages: Yellow
  - Success messages: Green
  - Normal messages: Default color

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

---

# 自动磁盘分区挂载脚本

这是一个用于自动检测、分区、格式化和挂载磁盘的Shell脚本。脚本提供了英文和中文两个版本，可以根据需要选择使用。

## 功能特点

- 自动检测磁盘分区状态
- 自动创建和扩展分区
- 自动格式化分区为ext4文件系统
- 自动挂载分区到/mnt目录
- 支持失败重试机制（最多3次）
- 详细的日志记录
- 彩色输出支持
- 排除系统关键磁盘（/dev/vda*, /dev/sda*, /dev/loop*）

## 文件说明

- `auto_disk_partition_mount.sh`: 英文版本脚本
- `auto_disk_partition_mount_cn.sh`: 中文版本脚本

## 系统要求

- Linux操作系统
- root权限
- 以下命令可用：
  - fdisk
  - partprobe
  - mkfs.ext4
  - mount
  - umount
  - blkid
  - lsblk
  - resize2fs

## 使用方法

1. 确保脚本具有执行权限：
```bash
chmod +x auto_disk_partition_mount.sh
# 或
chmod +x auto_disk_partition_mount_cn.sh
```

2. 使用root权限运行脚本：
```bash
sudo ./auto_disk_partition_mount.sh
# 或
sudo ./auto_disk_partition_mount_cn.sh
```

## 设置开机自启动

### 方法一：使用systemd服务（推荐）

1. 创建服务文件：
```bash
sudo nano /etc/systemd/system/auto-disk-mount.service
```

2. 添加以下内容：
```ini
[Unit]
Description=Auto Disk Partition and Mount Service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/path/to/auto_disk_partition_mount.sh
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

3. 重新加载systemd配置：
```bash
sudo systemctl daemon-reload
```

4. 启用服务：
```bash
sudo systemctl enable auto-disk-mount.service
```

5. 启动服务：
```bash
sudo systemctl start auto-disk-mount.service
```

6. 检查服务状态：
```bash
sudo systemctl status auto-disk-mount.service
```

### 方法二：使用rc.local（适用于使用systemd的系统）

1. 编辑rc.local文件：
```bash
sudo nano /etc/rc.local
```

2. 在exit 0之前添加：
```bash
/path/to/auto_disk_partition_mount.sh
```

3. 确保rc.local服务已启用：
```bash
sudo systemctl enable rc-local.service
```

### 方法三：使用crontab

1. 编辑root用户的crontab：
```bash
sudo crontab -e
```

2. 添加以下行：
```
@reboot /path/to/auto_disk_partition_mount.sh
```

注意：
- 请将`/path/to/auto_disk_partition_mount.sh`替换为脚本的实际路径
- 建议使用方法一（systemd服务），这是最现代和推荐的方式
- 确保脚本具有执行权限
- 建议在设置开机自启动前，先在手动模式下测试脚本是否正常工作

## 日志记录

- 日志文件位置：`/var/log/auto_disk_partition_mount.log`
- 日志包含时间戳和日志级别
- 控制台输出支持颜色区分：
  - 错误信息：红色
  - 警告信息：黄色
  - 成功信息：绿色
  - 普通信息：默认颜色

## 工作流程

1. 检查root权限
2. 扫描系统中的块设备
3. 排除系统关键磁盘
4. 对每个可用磁盘：
   - 检查是否已分区
   - 如未分区，创建分区
   - 检查分区是否使用全部磁盘空间
   - 如未使用全部空间，扩展分区
   - 检查分区是否已格式化
   - 如未格式化，格式化为ext4
   - 挂载分区到/mnt目录
   - 如挂载失败，最多重试3次

## 安全说明

- 脚本会排除系统关键磁盘（/dev/vda*, /dev/sda*, /dev/loop*）
- 建议在运行脚本前备份重要数据
- 脚本需要root权限运行
- 挂载失败时会自动清理临时文件和挂载点

## 注意事项

- 运行脚本前请确保了解其功能
- 建议在测试环境中先进行测试
- 脚本会修改磁盘分区表，请谨慎使用
- 确保系统有足够的磁盘空间

## 错误处理

- 脚本包含完整的错误处理机制
- 挂载失败时会自动重试（最多3次）
- 每次重试前会清理之前的操作
- 3次重试失败后会跳过该磁盘

## 贡献

欢迎提交问题和改进建议。如果您想贡献代码，请：

1. Fork 本仓库
2. 创建您的特性分支
3. 提交您的改动
4. 推送到您的分支
5. 创建一个 Pull Request

## 许可证

MIT License 