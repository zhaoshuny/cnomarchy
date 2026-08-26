#!/usr/bin/env bash
# CNomarchy Wine/Proton 兼容层设置脚本（L3 Windows 兼容）
# 用法: bash compat/wine/setup.sh
#
# 功能:
#   - 配置 Wine 环境
#   - 安装 Bottles（Wine 图形化管理）
#   - 配置 Steam + Proton
#   - 常用 Windows 软件一键安装脚本

set -e -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ============================================================
# 1. Wine 基础配置
# ============================================================
info "配置 Wine 环境..."

# 检查 Wine
if ! command -v wine &>/dev/null; then
    error "wine 未安装。请先运行: sudo pacman -S wine wine-mono wine-gecko winetricks"
fi

WINE_VERSION="$(wine --version 2>/dev/null || echo 'unknown')"
ok "Wine 版本: $WINE_VERSION"

# 默认 Wine 前缀
USER_NAME="$(logname 2>/dev/null || echo cnomarchy)"
USER_HOME="/home/$USER_NAME"
WINEPREFIX_DEFAULT="$USER_HOME/.wine"

# 初始化 Wine 前缀（如果不存在）
if [ ! -d "$WINEPREFIX_DEFAULT" ]; then
    info "初始化默认 Wine 前缀..."
    export WINEPREFIX="$WINEPREFIX_DEFAULT"
    export WINEARCH=win64
    wineboot --init 2>/dev/null || true
    ok "Wine 前缀初始化完成"
fi

# 中文环境变量
cat > "$USER_HOME/.config/wine-env.sh" <<'ENV'
# Wine 中文环境配置
export WINEPREFIX="$HOME/.wine"
export WINEARCH=win64
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
# 字体平滑
export FREETYPE_PROPERTIES="truetype:interpreter-version=35"
ENV
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/wine-env.sh"

# ============================================================
# 2. 安装 Bottles（通过 Flatpak）
# ============================================================
info "安装 Bottles（Wine 图形化管理工具）..."

if command -v flatpak &>/dev/null; then
    if flatpak list | grep -q com.usebottles.bottles; then
        info "Bottles 已安装，跳过"
    else
        flatpak install -y flathub com.usebottles.bottles 2>/dev/null && ok "Bottles 安装成功" || warn "Bottles 安装失败"
    fi
else
    warn "flatpak 未安装，跳过 Bottles 安装"
fi

# ============================================================
# 3. 配置 Steam + Proton
# ============================================================
info "配置 Steam + Proton..."

# 检查 Steam
if ! command -v steam &>/dev/null; then
    warn "steam 未安装。请运行: sudo pacman -S steam steam-native-runtime"
    warn "注意：Steam 需要 multilib 源已启用（pacman.conf 中已配置）"
else
    ok "Steam 已安装"

    # 启用 Proton（需要用户首次启动 Steam 后在设置中启用）
    STEAM_CONFIG="$USER_HOME/.steam/steam/steam_dev.cfg"
    mkdir -p "$(dirname "$STEAM_CONFIG")"

    info "Proton 配置说明:"
    info "  1. 启动 Steam 并登录"
    info "  2. 设置 → Steam Play → 勾选 'Enable Steam Play for supported titles'"
    info "  3. 勾选 'Enable Steam Play for all other titles'"
    info "  4. 选择 Proton 版本（推荐 Proton Experimental 或 Proton GE）"
    info "  5. 重启 Steam"
    echo ""

    # 安装 ProtonUp-Qt（Proton 版本管理工具）
    if command -v flatpak &>/dev/null; then
        if ! flatpak list | grep -q net.davidotek.pupgui2; then
            info "安装 ProtonUp-Qt（Proton 版本管理）..."
            flatpak install -y flathub net.davidotek.pupgui2 2>/dev/null && ok "ProtonUp-Qt 安装成功" || warn "ProtonUp-Qt 安装失败"
        fi
    fi
fi

# ============================================================
# 4. 常用 Windows 软件安装脚本
# ============================================================
info "创建常用 Windows 软件一键安装脚本..."

SCRIPTS_DIR="$USER_HOME/.local/bin/wine-apps"
mkdir -p "$SCRIPTS_DIR"
chown -R "$USER_NAME:$USER_NAME" "$SCRIPTS_DIR"

# 通用安装函数
cat > "$SCRIPTS_DIR/common.sh" <<'COMMON'
#!/usr/bin/env bash
# 通用 Wine 应用安装函数

# 下载文件
download() {
    local url="$1" output="$2"
    echo "下载: $url"
    if command -v aria2c &>/dev/null; then
        aria2c -x 16 -s 16 -o "$output" "$url"
    else
        curl -L -o "$output" "$url"
    fi
}

# 创建独立 Bottle
create_bottle() {
    local name="$1" prefix="$HOME/.bottles/$name"
    if [ ! -d "$prefix" ]; then
        echo "创建 Bottle: $name"
        WINEPREFIX="$prefix" WINEARCH=win64 wineboot --init
        # 安装常用组件
        WINEPREFIX="$prefix" winetricks -q dotnet48 cjkfonts 2>/dev/null || true
    fi
}

# 运行安装程序
run_installer() {
    local prefix="$1" installer="$2"
    WINEPREFIX="$prefix" wine "$installer"
}
COMMON
chmod +x "$SCRIPTS_DIR/common.sh"

# 网易云音乐（Windows 版，因为 Linux 版已停更）
cat > "$SCRIPTS_DIR/install-netease-music.sh" <<'APP'
#!/usr/bin/env bash
# 安装网易云音乐（Windows 版 via Wine）
source "$(dirname "$0")/common.sh"

BOTTLE_NAME="netease-music"
PREFIX="$HOME/.bottles/$BOTTLE_NAME"
INSTALLER="/tmp/netease-music-setup.exe"
DOWNLOAD_URL="https://d1.music.126.net/dmusic/NeteaseCloudMusic_Music_0.0.0.1.exe"

create_bottle "$BOTTLE_NAME"
download "$DOWNLOAD_URL" "$INSTALLER"
run_installer "$PREFIX" "$INSTALLER"
rm -f "$INSTALLER"

# 创建桌面快捷方式
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/netease-music-wine.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=网易云音乐 (Wine)
Exec=env WINEPREFIX="$PREFIX" wine "$PREFIX/drive_c/Program Files (x86)/Netease/CloudMusic/cloudmusic.exe"
Icon=netease-cloud-music
Categories=AudioVideo;Audio;
Keywords=music;netease;wine;
DESKTOP

echo "网易云音乐安装完成！"
APP
chmod +x "$SCRIPTS_DIR/install-netease-music.sh"

# 微信（Windows 版备用，如果原生 Linux 版有问题）
cat > "$SCRIPTS_DIR/install-wechat-wine.sh" <<'APP'
#!/usr/bin/env bash
# 安装微信（Windows 版 via Wine，备用方案）
# 注意：推荐使用原生 Linux 版微信（Flatpak: com.tencent.WeChat）
# 此脚本仅在原生版不可用时使用
source "$(dirname "$0")/common.sh"

echo "⚠️  警告：推荐使用原生 Linux 版微信"
echo "   flatpak install flathub com.tencent.WeChat"
echo ""
read -rp "是否继续安装 Windows 版微信？(y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

BOTTLE_NAME="wechat"
PREFIX="$HOME/.bottles/$BOTTLE_NAME"
INSTALLER="/tmp/wechat-setup.exe"
DOWNLOAD_URL="https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe"

create_bottle "$BOTTLE_NAME"
download "$DOWNLOAD_URL" "$INSTALLER"
run_installer "$PREFIX" "$INSTALLER"
rm -f "$INSTALLER"
echo "微信（Windows版）安装完成！"
APP
chmod +x "$SCRIPTS_DIR/install-wechat-wine.sh"

ok "常用软件安装脚本创建完成: $SCRIPTS_DIR"

# ============================================================
# 5. 兼容性数据库
# ============================================================
info "创建兼容性数据库..."

COMPAT_DB="$USER_HOME/.config/cnomarchy/compat-db.json"
mkdir -p "$(dirname "$COMPAT_DB")"

cat > "$COMPAT_DB" <<'DB'
{
  "version": "1.0",
  "last_updated": "2026-08-26",
  "apps": [
    {
      "name": "微信",
      "best_method": "flatpak",
      "flatpak_id": "com.tencent.WeChat",
      "native": true,
      "wine_rating": "gold",
      "notes": "腾讯官方 Linux 原生版，功能完整"
    },
    {
      "name": "QQ",
      "best_method": "flatpak",
      "flatpak_id": "com.qq.QQ",
      "native": true,
      "wine_rating": "gold",
      "notes": "NT QQ Linux 版"
    },
    {
      "name": "钉钉",
      "best_method": "native",
      "native": true,
      "wine_rating": "silver",
      "notes": "有官方 .deb 包，Arch 上可通过 debtap 转换"
    },
    {
      "name": "WPS Office",
      "best_method": "flatpak",
      "flatpak_id": "cn.wps.wps_365",
      "native": true,
      "wine_rating": "gold",
      "notes": "对 MS Office 兼容性最好的 Linux 办公软件"
    },
    {
      "name": "网易云音乐",
      "best_method": "wine",
      "native": false,
      "wine_rating": "gold",
      "install_script": "wine-apps/install-netease-music.sh",
      "notes": "Linux 版已停更（2026.3），推荐 Wine 运行 Windows 版或用 Proton"
    },
    {
      "name": "Photoshop",
      "best_method": "alternative",
      "native": false,
      "wine_rating": "silver",
      "alternatives": ["GIMP (flatpak: org.gimp.GIMP)", "Krita (flatpak: org.kde.krita)"],
      "notes": "CS6 可在 Wine 下运行，CC 以上版本不稳定。推荐 GIMP/Krita"
    },
    {
      "name": "Microsoft Office",
      "best_method": "alternative",
      "native": false,
      "wine_rating": "bronze",
      "alternatives": ["WPS Office", "OnlyOffice", "LibreOffice", "Microsoft 365 (网页版)"],
      "notes": "Office 2010-2016 可在 Wine 下运行但有缺陷。推荐 WPS 或网页版 Microsoft 365"
    },
    {
      "name": "抖音",
      "best_method": "waydroid",
      "native": false,
      "waydroid_package": "com.ss.android.ugc.aweme",
      "notes": "通过 Waydroid 安卓子系统运行"
    },
    {
      "name": "小红书",
      "best_method": "waydroid",
      "native": false,
      "waydroid_package": "com.xingin.xhs",
      "notes": "通过 Waydroid 安卓子系统运行"
    },
    {
      "name": "网银客户端",
      "best_method": "cloud",
      "native": false,
      "wine_rating": "garbage",
      "notes": "依赖 Windows 内核驱动（U盾），Wine 无法运行。推荐云桌面或手机银行 App"
    },
    {
      "name": "Steam 游戏",
      "best_method": "proton",
      "native": true,
      "notes": "Steam 原生 Linux 版 + Proton 兼容层，大部分 Windows 游戏可运行"
    }
  ]
}
DB
chown "$USER_NAME:$USER_NAME" "$COMPAT_DB"
ok "兼容性数据库创建完成"

# ============================================================
# 6. 完成
# ============================================================
echo ""
info "=========================================="
info "  Wine/Proton 兼容层设置完成"
info "=========================================="
echo ""
info "使用方式:"
info "  Bottles (图形化):  flatpak run com.usebottles.bottles"
info "  Steam (游戏):      steam"
info "  ProtonUp-Qt:       flatpak run net.davidotek.pupgui2"
info "  网易云音乐:        bash $SCRIPTS_DIR/install-netease-music.sh"
echo ""
info "兼容性查询:"
info "  数据库位置: $COMPAT_DB"
info "  包含常用软件的最佳运行方式和评级"
echo ""
warn "注意:"
warn "  - Wine 不是万能的，依赖内核驱动的软件（网银、反作弊）无法运行"
warn "  - .NET 4.8+ 软件可能需要额外配置"
warn "  - 游戏推荐用 Steam + Proton，不要用纯 Wine"
warn "  - 遇到问题可使用 Bottles 图形化管理不同的 Wine 前缀"
echo ""
ok "Wine/Proton 兼容层就绪！"

exit 0
