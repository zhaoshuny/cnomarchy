#!/bin/bash
set -e

echo "=== 安装 archiso ==="
pacman -Sy --noconfirm archiso

echo "=== 配置国内镜像加速 ==="
cat > /etc/pacman.d/mirrorlist <<'MIRROR'
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR

echo "=== 开始构建 ==="
echo "构建时间预计 20-40 分钟，请耐心等待..."
cd /build
mkarchiso -v -m iso -w /tmp/cnomarchy-work -o /out /build/iso

echo "=== 构建完成 ==="
ls -lh /out/
