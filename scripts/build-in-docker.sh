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

echo "=== mkarchiso 完整帮助 ==="
mkarchiso 2>&1 || true
echo "=== 帮助结束 ==="

echo "=== 尝试构建（不带 -w -o）==="
cd /build
mkarchiso -v /build/iso 2>&1 || echo "构建失败，退出码: $?"

echo "=== 检查输出 ==="
ls -la /build/out/ 2>/dev/null || echo "out 目录不存在"
ls -la /out/ 2>/dev/null || echo "/out 目录不存在"
find / -name "*.iso" -type f 2>/dev/null | head -5 || echo "未找到 ISO 文件"
