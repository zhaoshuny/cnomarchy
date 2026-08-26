#!/bin/bash
set -e

echo "=== 安装 archiso ==="
pacman -Sy --noconfirm archiso

echo "=== 查看默认 profile 位置 ==="
ls -la /usr/share/archiso/configs/ 2>/dev/null || echo "默认 configs 目录不存在"
find /usr/share/archiso -name "profiledef.sh" 2>/dev/null | head -5

echo "=== 查看默认 releng profile 的 profiledef.sh ==="
DEFAULT_PROFILE="/usr/share/archiso/configs/releng"
if [ -f "$DEFAULT_PROFILE/profiledef.sh" ]; then
    cat "$DEFAULT_PROFILE/profiledef.sh"
else
    echo "默认 releng profile 不存在，尝试查找其他 profile"
    find /usr/share/archiso -type d -name "configs" 2>/dev/null
fi

echo "=== 默认 profile 的文件结构 ==="
if [ -d "$DEFAULT_PROFILE" ]; then
    find "$DEFAULT_PROFILE" -type f | head -30
fi

echo "=== 我的 profile 的 profiledef.sh ==="
cat /build/iso/profiledef.sh

echo "=== 尝试用默认 profile 构建（最小测试）==="
mkdir -p /tmp/test-out
mkarchiso -v -m iso -w /tmp/test-work -o /tmp/test-out "$DEFAULT_PROFILE" 2>&1 | tail -50 || echo "默认 profile 构建失败，退出码: $?"

echo "=== 检查默认 profile 构建结果 ==="
ls -la /tmp/test-out/ 2>/dev/null || echo "test-out 目录不存在"
