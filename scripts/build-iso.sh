#!/usr/bin/env bash
# CNomarchy ISO 构建脚本
# 用法: sudo bash scripts/build-iso.sh
#
# 前置要求:
#   - Arch Linux 系统（或任何安装了 archiso 的发行版）
#   - 至少 4 核 8G 内存，50G 可用磁盘空间
#   - 已运行 scripts/setup-build-env.sh 安装构建依赖
#
# 产物: out/cnomarchy-<日期>-x86_64.iso

set -e -u

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

# ============================================================
# 检查权限
# ============================================================
if [ "$EUID" -ne 0 ]; then
    error "请使用 root 权限运行: sudo bash scripts/build-iso.sh"
fi

# ============================================================
# 路径配置
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ISO_PROFILE_DIR="$PROJECT_DIR/iso"
OUTPUT_DIR="$PROJECT_DIR/out"
WORK_DIR="$PROJECT_DIR/work"

# 日期戳
DATE_STAMP="$(date +%Y.%m.%d)"
ISO_FILENAME="cnomarchy-${DATE_STAMP}-x86_64.iso"

info "项目目录: $PROJECT_DIR"
info "ISO Profile: $ISO_PROFILE_DIR"
info "输出目录: $OUTPUT_DIR"
info "工作目录: $WORK_DIR"

# ============================================================
# 检查依赖
# ============================================================
info "检查构建依赖..."

if ! command -v mkarchiso &>/dev/null; then
    error "mkarchiso 未安装。请先运行: sudo bash scripts/setup-build-env.sh"
fi

# 检查 archiso 版本
ARCHISO_VERSION="$(pacman -Q archiso 2>/dev/null | awk '{print $2}' || echo 'unknown')"
info "archiso 版本: $ARCHISO_VERSION"

# 检查磁盘空间（至少 20G 可用）
AVAILABLE_SPACE_KB="$(df -k "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
AVAILABLE_SPACE_GB="$((AVAILABLE_SPACE_KB / 1024 / 1024))"
if [ "$AVAILABLE_SPACE_GB" -lt 20 ]; then
    warn "可用磁盘空间: ${AVAILABLE_SPACE_GB}GB，建议至少 20GB"
    read -rp "空间不足，是否继续？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "构建已取消"
    fi
else
    ok "可用磁盘空间: ${AVAILABLE_SPACE_GB}GB"
fi

# ============================================================
# 检查 ISO Profile 完整性
# ============================================================
info "检查 ISO Profile 完整性..."

MISSING_FILES=()
[ -f "$ISO_PROFILE_DIR/profiledef.sh" ] || MISSING_FILES+=("profiledef.sh")
[ -f "$ISO_PROFILE_DIR/packages.x86_64" ] || MISSING_FILES+=("packages.x86_64")
[ -f "$ISO_PROFILE_DIR/pacman.conf" ] || MISSING_FILES+=("pacman.conf")
[ -f "$ISO_PROFILE_DIR/airootfs/customize.sh" ] || MISSING_FILES+=("airootfs/customize.sh")

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    error "缺少必要文件: ${MISSING_FILES[*]}"
fi
ok "ISO Profile 完整"

# ============================================================
# 清理旧的构建产物
# ============================================================
info "清理旧的构建工作目录..."
if [ -d "$WORK_DIR" ]; then
    warn "工作目录已存在，将删除: $WORK_DIR"
    rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# 验证 Omarchy 源可用性（可选）
# ============================================================
info "检查 Omarchy 软件源可用性..."
OMARCHY_REPO_URL="$(grep -A1 '^\[omarchy\]' "$ISO_PROFILE_DIR/pacman.conf" | grep 'Server =' | head -1 | awk '{print $3}')"
if [ -n "$OMARCHY_REPO_URL" ]; then
    info "Omarchy 源: $OMARCHY_REPO_URL"
    if curl -s --connect-timeout 5 --max-time 10 "$OMARCHY_REPO_URL" >/dev/null 2>&1; then
        ok "Omarchy 源可访问"
    else
        warn "Omarchy 源不可访问！Quickshell/omarchy-* 包将无法安装"
        warn "构建可能失败。如需跳过，请编辑 iso/packages.x86_64 注释掉相关包"
        read -rp "是否继续构建？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "构建已取消"
        fi
    fi
else
    warn "未配置 Omarchy 源，将使用基础 Hyprland + waybar"
fi

# ============================================================
# 开始构建
# ============================================================
info "=========================================="
info "  开始构建 CNomarchy ISO"
info "  这可能需要 15-60 分钟，取决于网络和硬件"
info "=========================================="

BUILD_START_TIME="$(date +%s)"

# 复制 profile 到工作目录（避免修改源文件）
cp -r "$ISO_PROFILE_DIR"/* "$WORK_DIR/"

# 执行构建
# -v: 详细输出
# -w: 工作目录
# -o: 输出目录
cd "$PROJECT_DIR"
mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" "$WORK_DIR"

BUILD_END_TIME="$(date +%s)"
BUILD_DURATION="$((BUILD_END_TIME - BUILD_START_TIME))"
BUILD_MINUTES="$((BUILD_DURATION / 60))"
BUILD_SECONDS="$((BUILD_DURATION % 60))"

# ============================================================
# 构建完成
# ============================================================
echo ""
info "=========================================="
info "  构建完成！"
info "  耗时: ${BUILD_MINUTES}分${BUILD_SECONDS}秒"
info "=========================================="

# 查找生成的 ISO
GENERATED_ISO="$(ls -t "$OUTPUT_DIR"/*.iso 2>/dev/null | head -1)"
if [ -n "$GENERATED_ISO" ]; then
    ISO_SIZE="$(du -h "$GENERATED_ISO" | awk '{print $1}')"
    ok "ISO 文件: $GENERATED_ISO"
    ok "文件大小: $ISO_SIZE"

    # 计算 SHA256
    info "计算 SHA256 校验和..."
    sha256sum "$GENERATED_ISO" > "${GENERATED_ISO}.sha256"
    ok "校验和: ${GENERATED_ISO}.sha256"

    echo ""
    info "下一步:"
    info "  1. 用 QEMU 测试: bash scripts/test-in-qemu.sh"
    info "  2. 写入 U 盘: sudo dd if=$GENERATED_ISO of=/dev/sdX bs=4M status=progress"
    info "  3. 用 Ventoy: 复制 ISO 到 Ventoy U 盘"
else
    error "未找到生成的 ISO 文件，请检查上方错误日志"
fi

# 清理工作目录（可选，保留以便调试）
# rm -rf "$WORK_DIR"
info "工作目录保留在: $WORK_DIR（调试用，确认无误后可删除）"

exit 0
