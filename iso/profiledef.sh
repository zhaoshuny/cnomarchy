#!/usr/bin/env bash
# archiso profile 定义 - CNomarchy
# 参考: https://gitlab.archlinux.org/archlinux/archiso

set -e -u

# 镜像名称（ISO 文件名前缀）
iso_name=cnomarchy
# 镜像标签
iso_label="CNOMARCHY_$(date +%Y%m)"
# 安装目录（ISO 内的目录名）
install_dir=cnomarchy
# 发布者
iso_publisher="CNomarchy <https://github.com/your-org/cnomarchy>"
# 应用名
iso_application="CNomarchy Live/Rescue CD"
# 架构
arch="x86_64"
# 压缩类型：zstd（快，体积稍大）或 xz（慢，体积小）
# 生产用 zstd，发布候选可用 xz
sfs_comp="zstd"
sfs_comp_opt="-Xcompression-level 19 -Xthreads=0"
# 引导加载器
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
# 内核
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
# 权限数组（文件路径 所有者 权限）
# 格式: "路径|uid:gid|mode"
file_permissions=(
  # sudo 配置
  "/etc/sudoers|0:0|0440"
  "/etc/sudoers.d|0:0|0750"
  # GPG
  "/etc/polkit-1/rules.d|0:0|0750"
  # 影子密码
  "/etc/shadow|0:0|0000"
  "/etc/gshadow|0:0|0000"
  # 登录管理器（如果用 sddm/gdm）
  # 这里用 Hyprland 自动登录，不需要显示管理器
)
