#!/usr/bin/env bash
# CNomarchy Flatpak 兼容层设置脚本（L1 原生 Linux）
# 用法: bash compat/flatpak/setup.sh
#
# 功能:
#   - 添加 Flathub 国内镜像
#   - 安装常用国产软件
#   - 配置 Flatpak 权限

set -e -u

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 检查 flatpak
if ! command -v flatpak &>/dev/null; then
    error "flatpak 未安装。请先运行: sudo pacman -S flatpak"
fi

# ============================================================
# 1. 添加 Flathub 远程源（国内镜像优先）
# ============================================================
info "配置 Flathub 远程源..."

# 检查是否已添加
if flatpak remotes | grep -q flathub; then
    info "Flathub 已添加，更新 URL..."
    flatpak remote-modify --url "https://mirror.tuna.tsinghua.edu.cn/flathub/flathub.flatpakrepo" flathub 2>/dev/null || true
else
    info "添加 Flathub 国内镜像（清华 TUNA）..."
    flatpak remote-add --if-not-exists flathub \
        "https://mirror.tuna.tsinghua.edu.cn/flathub/flathub.flatpakrepo"
fi
ok "Flathub 远程源配置完成"

# ============================================================
# 2. 安装常用软件
# ============================================================
info "安装常用 Flatpak 应用..."

# 定义要安装的应用列表
# 格式: "包名|显示名称|分类"
APPS=(
    # 社交沟通
    "com.tencent.WeChat|微信|社交"
    "com.qq.QQ|QQ|社交"
    "com.tencent.wemeet|腾讯会议|社交"
    "cn.feishu.Feishu|飞书|办公"
    # "com.alibaba.DingTalk|钉钉|办公"  # 钉钉 Flatpak 包名待确认
    # 办公
    "cn.wps.wps_365|WPS Office|办公"
    "org.onlyoffice.desktopeditors|OnlyOffice|办公"
    "org.mozilla.Thunderbird|雷鸟邮件|办公"
    # 浏览器
    "com.google.Chrome|Chrome|网络"
    "org.mozilla.firefox|Firefox|网络"
    "com.microsoft.Edge|Edge|网络"
    # 开发工具
    "com.visualstudio.code|VS Code|开发"
    "com.jetbrains.IntelliJ-IDEA-Community|IDEA Community|开发"
    "io.podman_desktop.PodmanDesktop|Podman Desktop|开发"
    # 媒体
    "com.spotify.Client|Spotify|媒体"
    "org.videolan.VLC|VLC|媒体"
    "org.gimp.GIMP|GIMP|图像"
    "org.inkscape.Inkscape|Inkscape|图像"
    "org.blender.Blender|Blender|3D"
    "com.obsproject.Studio|OBS Studio|媒体"
    "com.github.tauri-apps.build-alpha|音乐标签|媒体"  # 占位
    # 工具
    "com.bitwarden.desktop|Bitwarden|安全"
    "org.keepassxc.KeePassXC|KeePassXC|安全"
    "io.github.flattool.Warehouse|Warehouse(Flatpak管理)|工具"
    "com.github.tchx84.Flatseal|Flatseal(权限管理)|工具"
    "org.nickvision.tubeconverter|Tube Converter|下载"
    "fr.handbrake.ghb|HandBrake|媒体"
    # 笔记
    "md.obsidian.Obsidian|Obsidian|笔记"
    "org.logseq.Logseq|Logseq|笔记"
    "app.libreoffice.LibreOffice|LibreOffice|办公"
    # 通讯
    "org.signal.Signal|Signal|社交"
    "org.telegram.desktop|Telegram|社交"
    "com.discordapp.Discord|Discord|社交"
)

# 安装统计
SUCCESS=0
FAILED=0
SKIPPED=0

for app in "${APPS[@]}"; do
    IFS='|' read -r pkg_id name category <<< "$app"

    # 检查是否已安装
    if flatpak list | grep -q "$pkg_id"; then
        info "[$category] $name 已安装，跳过"
        ((SKIPPED++))
        continue
    fi

    info "[$category] 安装 $name ($pkg_id)..."
    if flatpak install -y flathub "$pkg_id" 2>/dev/null; then
        ok "[$category] $name 安装成功"
        ((SUCCESS++))
    else
        warn "[$category] $name 安装失败（包名可能不正确或网络问题）"
        ((FAILED++))
    fi
done

echo ""
info "=========================================="
info "  Flatpak 安装完成"
info "  成功: $SUCCESS | 失败: $FAILED | 已存在: $SKIPPED"
info "=========================================="

# ============================================================
# 3. 配置常用权限
# ============================================================
info "配置应用权限..."

# 微信：允许访问下载目录、输入法
if flatpak list | grep -q com.tencent.WeChat; then
    flatpak override com.tencent.WeChat \
        --filesystem=xdg-download \
        --filesystem=xdg-pictures \
        --socket=wayland \
        --socket=x11 2>/dev/null || true
    ok "微信权限配置完成"
fi

# WPS：允许访问文档目录
if flatpak list | grep -q cn.wps.wps_365; then
    flatpak override cn.wps.wps_365 \
        --filesystem=home \
        --socket=wayland \
        --socket=x11 2>/dev/null || true
    ok "WPS 权限配置完成"
fi

# VS Code：允许访问家目录、Git、终端
if flatpak list | grep -q com.visualstudio.code; then
    flatpak override com.visualstudio.code \
        --filesystem=home \
        --filesystem=host-os \
        --talk-name=org.freedesktop.Flatpak \
        --socket=wayland \
        --socket=x11 2>/dev/null || true
    ok "VS Code 权限配置完成"
fi

# ============================================================
# 4. 提示
# ============================================================
echo ""
info "安装的应用可以在应用菜单中找到，或通过命令行运行:"
info "  flatpak run com.tencent.WeChat    # 微信"
info "  flatpak run cn.wps.wps_365        # WPS"
info "  flatpak run com.visualstudio.code  # VS Code"
echo ""
info "管理 Flatpak 应用:"
info "  flatpak list                    # 列出已安装"
info "  flatpak update                  # 更新所有"
info "  flatpak uninstall <包名>         # 卸载"
info "  flatpak run <包名>               # 运行"
echo ""
ok "Flatpak 兼容层设置完成！"

exit 0
