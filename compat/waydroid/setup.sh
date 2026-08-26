#!/usr/bin/env bash
# CNomarchy Waydroid 安卓子系统设置脚本（L2 安卓兼容）
# 用法: sudo bash compat/waydroid/setup.sh
#
# 功能:
#   - 从 AUR 安装 Waydroid
#   - 下载国内 Android 镜像
#   - 配置桌面集成
#   - 安装常用安卓应用

set -e -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    error "请使用 root 权限运行: sudo bash compat/waydroid/setup.sh"
fi

# ============================================================
# 0. 前置检查
# ============================================================
info "检查前置条件..."

# 检查 Wayland（Waydroid 必须在 Wayland 下运行）
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${XDG_SESSION_TYPE:-}" ]; then
    warn "未检测到 Wayland 环境。Waydroid 需要 Wayland 会话。"
    warn "CNomarchy 默认使用 Hyprland (Wayland)，请确保在图形界面中运行此脚本。"
fi

if [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
    error "当前是 X11 会话，Waydroid 不支持 X11。请切换到 Wayland 会话（Hyprland）。"
fi

# 检查内核模块
info "检查内核模块..."
for mod in binder_linux ashmem; do
    if modinfo "$mod" &>/dev/null; then
        ok "内核模块 $mod: 可用"
    else
        warn "内核模块 $mod: 未找到（可能已内置到内核，或需要安装 linux-zen）"
    fi
done

# 检查 paru（AUR 助手）
if ! command -v paru &>/dev/null; then
    warn "paru 未安装，将先安装 paru..."
    # 安装 paru
    pacman -S --needed --noconfirm base-devel git
    TEMP_DIR="$(mktemp -d)"
    cd "$TEMP_DIR"
    runuser -l "$(logname 2>/dev/null || echo cnomarchy)" -c "
        cd $TEMP_DIR &&
        git clone https://aur.archlinux.org/paru.git &&
        cd paru &&
        makepkg -si --noconfirm
    " || error "paru 安装失败"
    cd -
    rm -rf "$TEMP_DIR"
    ok "paru 安装完成"
fi

# ============================================================
# 1. 安装 Waydroid
# ============================================================
info "从 AUR 安装 Waydroid..."

# 安装 waydroid 和 waydroid-image
runuser -l "$(logname 2>/dev/null || echo cnomarchy)" -c "
    paru -S --needed --noconfirm waydroid waydroid-image-gapps
" || error "Waydroid 安装失败"

ok "Waydroid 安装完成"

# ============================================================
# 2. 启用服务
# ============================================================
info "启用 Waydroid 服务..."

systemctl enable --now waydroid-container
ok "waydroid-container 服务已启用"

# ============================================================
# 3. 初始化 Waydroid（下载 Android 镜像）
# ============================================================
info "初始化 Waydroid..."
info "这将下载 Android 系统镜像（约 600MB），请确保网络畅通"

# 使用国内镜像源（如果可用）
# 官方源: https://sourceforge.net/projects/waydroid/files/images/
# 国内可尝试: 中科大镜像或直接用官方
WAYDROID_IMG_URL="https://sourceforge.net/projects/waydroid/files/images"

# 检查是否已初始化
if [ -f /var/lib/waydroid/waydroid.cfg ]; then
    warn "Waydroid 已初始化，跳过"
else
    info "下载 Android 镜像并初始化..."
    waydroid init \
        -s GAPPS \
        -c "${WAYDROID_IMG_URL}/system/lineage-18.1/20240106/waydroid_x86_64-GAPPS.img" \
        -v "${WAYDROID_IMG_URL}/vendor/lineage-18.1/20240106/waydroid_x86_64-MAINLINE.img" \
        || warn "官方镜像下载失败，尝试使用默认源..."

    # 如果上面失败，用默认源重试
    if [ ! -f /var/lib/waydroid/waydroid.cfg ]; then
        info "使用默认源重试..."
        waydroid init -s GAPPS || error "Waydroid 初始化失败，请检查网络连接"
    fi
fi

ok "Waydroid 初始化完成"

# ============================================================
# 4. 配置优化
# ============================================================
info "配置 Waydroid 优化..."

# 配置文件
WAYDROID_CFG="/var/lib/waydroid/waydroid.cfg"

if [ -f "$WAYDROID_CFG" ]; then
    # 启用多窗口
    if ! grep -q "persist.waydroid.multi_windows" "$WAYDROID_CFG"; then
        echo "persist.waydroid.multi_windows=true" >> "$WAYDROID_CFG"
    fi
    # 启用状态栏
    if ! grep -q "persist.waydroid.hide_status_bar" "$WAYDROID_CFG"; then
        echo "persist.waydroid.hide_status_bar=false" >> "$WAYDROID_CFG"
    fi
    # 屏幕密度
    if ! grep -q "ro.sf.lcd_density" "$WAYDROID_CFG"; then
        echo "ro.sf.lcd_density=240" >> "$WAYDROID_CFG"
    fi
    ok "Waydroid 配置优化完成"
fi

# ============================================================
# 5. 桌面集成
# ============================================================
info "配置桌面集成..."

# 创建 Waydroid 应用目录
USER_NAME="$(logname 2>/dev/null || echo cnomarchy)"
USER_HOME="/home/$USER_NAME"
APPLICATIONS_DIR="$USER_HOME/.local/share/applications"
mkdir -p "$APPLICATIONS_DIR"

# Waydroid 全界面启动器
cat > "$APPLICATIONS_DIR/waydroid-fullui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Waydroid (安卓子系统)
Comment=启动完整 Android 界面
Exec=waydroid show-full-ui
Icon=waydroid
Categories=System;Emulator;
Keywords=android;waydroid;emulator;
DESKTOP

# Waydroid 设置
cat > "$APPLICATIONS_DIR/waydroid-settings.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Waydroid 设置
Comment=Waydroid 安卓子系统设置
Exec=waydroid app launch com.android.settings
Icon=preferences-system
Categories=Settings;System;
DESKTOP

chown -R "$USER_NAME:$USER_NAME" "$APPLICATIONS_DIR"
ok "桌面快捷方式创建完成"

# ============================================================
# 6. 启动 Waydroid
# ============================================================
info "启动 Waydroid..."

# 启动会话（需要在用户会话中）
runuser -l "$USER_NAME" -c "waydroid session start &" 2>/dev/null || true
sleep 3

info "Waydroid 正在启动，首次启动可能需要 1-2 分钟..."

# ============================================================
# 7. 安装常用安卓应用
# ============================================================
echo ""
info "=========================================="
info "  安装常用安卓应用"
info "=========================================="
echo ""
info "通过 Google Play 商店安装应用（需要 Google 账号登录）"
info "或者通过 APK 文件安装: waydroid app install <apk文件>"
echo ""
info "推荐安装的应用:"
info "  - 抖音 (com.ss.android.ugc.aweme)"
info "  - 小红书 (com.xingin.xhs)"
info "  - 哔哩哔哩 (tv.danmaku.bili)"
info "  - 网易云音乐 (com.netease.cloudmusic)"
info "  - 美团 (com.sankuai.meituan)"
info "  - 饿了么 (me.ele)"
info "  - 12306 (com.MobileTicket)"
info "  - 支付宝 (com.eg.android.AlipayGphone)"
info "  - 各银行 App"
echo ""

# 尝试安装 F-Droid（开源应用商店，不需要 Google 账号）
info "安装 F-Droid（开源应用商店）..."
FDROID_APK="/tmp/f-droid.apk"
if curl -L -o "$FDROID_APK" "https://f-droid.org/F-Droid.apk" 2>/dev/null; then
    runuser -l "$USER_NAME" -c "waydroid app install $FDROID_APK" 2>/dev/null && ok "F-Droid 安装成功" || warn "F-Droid 安装失败"
    rm -f "$FDROID_APK"
else
    warn "F-Droid 下载失败"
fi

# ============================================================
# 8. 完成
# ============================================================
echo ""
info "=========================================="
info "  Waydroid 安卓子系统设置完成"
info "=========================================="
echo ""
info "常用命令:"
info "  waydroid show-full-ui          # 显示完整 Android 界面"
info "  waydroid app list              # 列出已安装应用"
info "  waydroid app launch <包名>      # 启动应用"
info "  waydroid app install <apk>     # 安装 APK"
info "  waydroid shell                  # 进入 Android shell"
info "  waydroid session stop           # 停止会话"
echo ""
info "注意事项:"
info "  - Waydroid 只能在 Wayland 下运行（CNomarchy 默认 Hyprland）"
info "  - 只支持 x86_64 CPU（Intel/AMD），不支持 ARM"
info "  - NVIDIA 显卡性能较差，建议 Intel/AMD 显卡"
info "  - 部分银行 App 会检测模拟器环境，可能无法使用"
info "  - 内存占用: 空闲约 1-2GB，运行 App 时 3-4GB"
echo ""
ok "Waydroid 安卓子系统就绪！"

exit 0
