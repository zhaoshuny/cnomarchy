#!/usr/bin/env bash
# CNomarchy ISO QEMU 测试脚本
# 用法: bash scripts/test-in-qemu.sh [iso文件路径]
#
# 如果不指定 ISO 路径，自动使用 out/ 目录下最新的 ISO

set -e -u

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============================================================
# 路径配置
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/out"

# ============================================================
# 确定 ISO 文件
# ============================================================
if [ $# -ge 1 ] && [ -f "$1" ]; then
    ISO_FILE="$1"
else
    # 自动查找最新的 ISO
    ISO_FILE="$(ls -t "$OUTPUT_DIR"/*.iso 2>/dev/null | head -1)"
fi

if [ -z "${ISO_FILE:-}" ] || [ ! -f "$ISO_FILE" ]; then
    error "未找到 ISO 文件。请先构建: sudo bash scripts/build-iso.sh"
fi

ok "使用 ISO: $ISO_FILE"
ISO_SIZE="$(du -h "$ISO_FILE" | awk '{print $1}')"
info "ISO 大小: $ISO_SIZE"

# ============================================================
# 检查 QEMU
# ============================================================
if ! command -v qemu-system-x86_64 &>/dev/null; then
    error "qemu-system-x86_64 未安装。请运行: sudo bash scripts/setup-build-env.sh"
fi

QEMU_VERSION="$(qemu-system-x86_64 --version | head -1)"
ok "QEMU: $QEMU_VERSION"

# 检查 KVM 加速
KVM_AVAILABLE=false
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_AVAILABLE=true
    ok "KVM 加速: 可用"
else
    warn "KVM 加速: 不可用（性能将大幅下降）"
    warn "  请确保: 1) CPU 支持虚拟化 2) BIOS 中启用 VT-x/AMD-V 3) 用户在 kvm 组"
fi

# 检查 OVMF（UEFI 固件）
OVMF_PATHS=(
    "/usr/share/OVMF/OVMF_CODE.fd"
    "/usr/share/edk2/x64/OVMF_CODE.fd"
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
    "/usr/share/qemu/edk2-x86_64-code.fd"
)
OVMF_CODE=""
for path in "${OVMF_PATHS[@]}"; do
    if [ -f "$path" ]; then
        OVMF_CODE="$path"
        break
    fi
done

if [ -n "$OVMF_CODE" ]; then
    ok "OVMF (UEFI): $OVMF_CODE"
else
    warn "OVMF (UEFI): 未找到，将使用 BIOS 引导"
    warn "  UEFI 引导更接近真实硬件，建议安装: edk2-ovmf"
fi

# ============================================================
# VM 配置
# ============================================================
# CPU 核心数（使用宿主机一半核心，至少 2 核）
HOST_CORES="$(nproc)"
VM_CORES=$((HOST_CORES / 2))
[ "$VM_CORES" -lt 2 ] && VM_CORES=2
[ "$VM_CORES" -gt 8 ] && VM_CORES=8

# 内存（使用宿主机一半，至少 2G）
HOST_MEM_KB="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
HOST_MEM_GB="$((HOST_MEM_KB / 1024 / 1024))"
VM_MEM_GB=$((HOST_MEM_GB / 2))
[ "$VM_MEM_GB" -lt 2 ] && VM_MEM_GB=2
[ "$VM_MEM_GB" -gt 16 ] && VM_MEM_GB=16

# 虚拟磁盘（用于测试安装到硬盘，默认 32G）
VM_DISK="$PROJECT_DIR/work/test-disk.qcow2"
VM_DISK_SIZE="32G"

# 显示配置
# - 如果你在 Wayland 下，用 gtk 或 wayland
# - 如果你在 X11 下，用 gtk
DISPLAY_TYPE="gtk"
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    DISPLAY_TYPE="gtk"
fi

info "VM 配置: ${VM_CORES} 核 / ${VM_MEM_GB}GB 内存 / ${VM_DISK_SIZE} 虚拟磁盘"

# ============================================================
# 创建虚拟磁盘（如果不存在）
# ============================================================
if [ ! -f "$VM_DISK" ]; then
    info "创建虚拟磁盘: $VM_DISK ($VM_DISK_SIZE)"
    mkdir -p "$(dirname "$VM_DISK")"
    qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
    ok "虚拟磁盘创建完成"
else
    info "使用已存在的虚拟磁盘: $VM_DISK"
fi

# ============================================================
# 启动 QEMU
# ============================================================
echo ""
info "=========================================="
info "  启动 QEMU 虚拟机"
info "  按 Ctrl+Alt+G 释放鼠标"
info "  关闭虚拟机窗口即退出"
info "=========================================="
echo ""

# 构建 QEMU 命令
QEMU_CMD="qemu-system-x86_64 \
    -m ${VM_MEM_GB}G \
    -smp ${VM_CORES} \
    -cpu host \
    -drive file=\"$ISO_FILE\",media=cdrom,readonly=on \
    -drive file=\"$VM_DISK\",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2222-:22 \
    -vga virtio \
    -display $DISPLAY_TYPE \
    -machine type=q35,accel=kvm \
    -usb \
    -device usb-tablet \
    -soundhw hda \
    -boot order=d"

# 如果 KVM 不可用，去掉 accel=kvm
if [ "$KVM_AVAILABLE" = false ]; then
    QEMU_CMD="${QEMU_CMD//accel=kvm/accel=tcg}"
    warn "使用 TCG 软件模拟（性能较差）"
fi

# 如果有 OVMF，使用 UEFI 引导
if [ -n "$OVMF_CODE" ]; then
    # 创建可写的 NVRAM
    OVMF_VARS="$PROJECT_DIR/work/ovmf-vars.fd"
    if [ ! -f "$OVMF_VARS" ]; then
        # 找到对应的 vars 文件
        OVMF_VARS_TEMPLATE="${OVMF_CODE//CODE/VARS}"
        if [ -f "$OVMF_VARS_TEMPLATE" ]; then
            cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
        else
            # 创建空的 vars 文件
            dd if=/dev/zero of="$OVMF_VARS" bs=1M count=64 2>/dev/null || true
        fi
    fi
    QEMU_CMD="$QEMU_CMD \
        -drive if=pflash,format=raw,readonly=on,file=\"$OVMF_CODE\" \
        -drive if=pflash,format=raw,file=\"$OVMF_VARS\""
fi

info "启动命令（简化）: qemu-system-x86_64 -m ${VM_MEM_GB}G -smp ${VM_CORES} ..."
echo ""

# 执行
eval "$QEMU_CMD"

echo ""
ok "QEMU 已退出"
info "虚拟磁盘保留在: $VM_DISK（可用于后续测试）"
info "如需重新测试安装，删除虚拟磁盘: rm $VM_DISK"

exit 0
