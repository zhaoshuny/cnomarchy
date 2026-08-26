#!/usr/bin/env bash
# shellcheck disable=SC2034
# archiso profile 定义 - CNomarchy
# 参考: /usr/share/archiso/configs/releng/profiledef.sh

iso_name="cnomarchy"
iso_label="CNOMARCHY_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="CNomarchy <https://github.com/zhaoshuny/cnomarchy>"
iso_application="CNomarchy Live/Rescue DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="cnomarchy"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/sudoers"]="0:0:440"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/polkit-1/rules.d"]="0:0:750"
)
