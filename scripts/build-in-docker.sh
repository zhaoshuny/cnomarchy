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
cat /etc/pacman.d/mirrorlist

echo "=== 调试信息 ==="
echo "Current directory: $(pwd)"
echo "ISO profile path: /build/iso"
ls -la /build/iso/
echo "---"
ls -la /build/iso/airootfs/
echo "---"
echo "mkarchiso version:"
mkarchiso --version 2>&1 || echo "mkarchiso --version failed"
echo "---"
echo "mkarchiso help:"
mkarchiso --help 2>&1 | head -30 || echo "mkarchiso --help failed"

echo "=== 开始构建 ==="
echo "构建时间预计 20-40 分钟，请耐心等待..."
mkarchiso -v -w /tmp/cnomarchy-work -o /out /build/iso

echo "=== 构建完成 ==="
ls -lh /out/
