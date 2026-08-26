#!/usr/bin/env bash
# CNomarchy 构建环境搭建脚本
# 用法: sudo bash scripts/setup-build-env.sh
#
# 功能:
#   - 安装 archiso 和构建依赖
#   - 配置构建环境
#   - 验证环境可用性

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
# 检查权限和系统
# ============================================================
if [ "$EUID" -ne 0 ]; then
    error "请使用 root 权限运行: sudo bash scripts/setup-build-env.sh"
fi

# 检测发行版
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO="$ID"
    info "检测到发行版: $DISTRO ($PRETTY_NAME)"
else
    error "无法检测发行版，请在 Arch Linux 或兼容发行版上运行"
fi

# ============================================================
# 安装构建依赖
# ============================================================
info "安装构建依赖..."

case "$DISTRO" in
    arch|archlinux|manjaro|endeavouros|garuda|cnomarchy)
        # Arch 系发行版
        pacman -Sy --needed --noconfirm \
            archiso \
            squashfs-tools \
            libisoburn \
            dosfstools \
            mtools \
            e2fsprogs \
            parted \
            git \
            curl \
            wget \
            rsync \
            qemu-desktop \
            edk2-ovmf \
            xorriso
        ok "构建依赖安装完成"
        ;;

    ubuntu|debian|linuxmint|pop|elementary|zorin)
        # Debian/Ubuntu 系
        warn "在 Debian/Ubuntu 上构建 Arch ISO 可能遇到兼容性问题"
        warn "建议使用 Arch Linux 或 Arch 系发行版作为构建环境"
        read -rp "是否继续？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "已取消"
        fi

        apt-get update
        apt-get install -y \
            arch-install-scripts \
            squashfs-tools \
            xorriso \
            mtools \
            dosfstools \
            e2fsprogs \
            parted \
            git \
            curl \
            wget \
            rsync \
            qemu-system-x86 \
            ovmf
        ok "构建依赖安装完成"
        ;;

    fedora|rhel|centos|rocky|almalinux)
        # Red Hat 系
        warn "在 Fedora/RHEL 上构建 Arch ISO 可能遇到兼容性问题"
        warn "建议使用 Arch Linux 作为构建环境"
        read -rp "是否继续？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "已取消"
        fi

        dnf install -y \
            arch-install-scripts \
            squashfs-tools \
            xorriso \
            mtools \
            dosfstools \
            e2fsprogs \
            parted \
            git \
            curl \
            wget \
            rsync \
            qemu-system-x86 \
            edk2-ovmf
        ok "构建依赖安装完成"
        ;;

    *)
        error "不支持的发行版: $DISTRO。请使用 Arch Linux 作为构建环境。"
        ;;
esac

# ============================================================
# 验证环境
# ============================================================
info "验证构建环境..."

# 检查 mkarchiso
if command -v mkarchiso &>/dev/null; then
    ok "mkarchiso: $(mkarchiso --version 2>/dev/null || echo 'available')"
else
    error "mkarchiso 未找到，安装可能失败"
fi

# 检查必要工具
REQUIRED_TOOLS=("mksquashfs" "xorriso" "mkfs.fat" "git" "curl")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool: 可用"
    else
        warn "$tool: 未找到（可能影响构建）"
    fi
done

# 检查内核模块（squashfs）
if modinfo squashfs &>/dev/null; then
    ok "squashfs 内核模块: 可用"
else
    warn "squashfs 内核模块: 未找到（构建可能失败）"
fi

# ============================================================
# 配置建议
# ============================================================
echo ""
info "=========================================="
info "  环境搭建完成"
info "=========================================="
echo ""
info "构建环境已就绪。下一步:"
echo ""
info "  1. 构建 ISO:"
info "     sudo bash scripts/build-iso.sh"
echo ""
info "  2. 用 QEMU 测试:"
info "     bash scripts/test-in-qemu.sh"
echo ""
warn "注意事项:"
warn "  - 构建需要下载大量包，建议使用有线网络"
warn "  - 首次构建可能需要 30-60 分钟"
warn "  - 确保有至少 20GB 可用磁盘空间"
warn "  - 建议在 Arch Linux 上构建，其他发行版可能有兼容性问题"
echo ""

# 如果不是 Arch 系，给出 Docker 构建方案
if [[ ! "$DISTRO" =~ arch|manjaro|endeavouros|garuda|cnomarchy ]]; then
    info "替代方案: 使用 Docker 构建（推荐非 Arch 用户）"
    info ""
    info "  # 拉取 Arch Docker 镜像"
    info "  docker pull archlinux:latest"
    info ""
    info "  # 运行构建容器"
    info "  docker run --privileged -v \$(pwd):/build -w /build archlinux:latest \\"
    info "    bash -c 'pacman -Sy --noconfirm archiso && bash scripts/build-iso.sh'"
    echo ""
fi

exit 0
