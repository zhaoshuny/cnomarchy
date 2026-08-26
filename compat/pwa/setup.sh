#!/usr/bin/env bash
# CNomarchy PWA 兼容层设置脚本（L4 Web 应用）
# 用法: bash compat/pwa/setup.sh
#
# 功能:
#   - 将常用网站封装为桌面应用（Chromium App 模式）
#   - 创建桌面快捷方式
#   - 配置图标

set -e -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

USER_NAME="$(logname 2>/dev/null || echo cnomarchy)"
USER_HOME="/home/$USER_NAME"
APPLICATIONS_DIR="$USER_HOME/.local/share/applications"
ICONS_DIR="$USER_HOME/.local/share/icons/hicolor/256x256/apps"
BIN_DIR="$USER_HOME/.local/bin"

mkdir -p "$APPLICATIONS_DIR" "$ICONS_DIR" "$BIN_DIR"

# 检查 Chromium
if ! command -v chromium &>/dev/null && ! command -v google-chrome &>/dev/null; then
    warn "Chromium/Chrome 未安装，PWA 功能需要浏览器"
    info "安装: sudo pacman -S chromium 或 flatpak install flathub com.google.Chrome"
fi

# 确定浏览器命令
BROWSER_CMD=""
if command -v chromium &>/dev/null; then
    BROWSER_CMD="chromium"
elif command -v google-chrome &>/dev/null; then
    BROWSER_CMD="google-chrome"
elif flatpak list 2>/dev/null | grep -q com.google.Chrome; then
    BROWSER_CMD="flatpak run com.google.Chrome"
fi

info "使用浏览器: ${BROWSER_CMD:-未找到}"

# ============================================================
# PWA 应用列表
# 格式: "名称|URL|分类|描述"
# ============================================================
PWAS=(
    "微信网页版|https://wx.qq.com|社交|微信网页版（聊天、传文件）"
    "钉钉|https://im.dingtalk.com|办公|钉钉网页版"
    "飞书|https://www.feishu.cn|办公|飞书网页版"
    "企业微信|https://work.weixin.qq.com|办公|企业微信网页版"
    "网易云音乐|https://music.163.com|媒体|网易云音乐网页版"
    "QQ音乐|https://y.qq.com|媒体|QQ音乐网页版"
    "哔哩哔哩|https://www.bilibili.com|媒体|哔哩哔哩网页版"
    "腾讯视频|https://v.qq.com|媒体|腾讯视频网页版"
    "爱奇艺|https://www.iqiyi.com|媒体|爱奇艺网页版"
    "优酷|https://www.youku.com|媒体|优酷网页版"
    "知乎|https://www.zhihu.com|资讯|知乎网页版"
    "微博|https://weibo.com|社交|微博网页版"
    "豆瓣|https://www.douban.com|资讯|豆瓣网页版"
    "淘宝|https://www.taobao.com|购物|淘宝网页版"
    "京东|https://www.jd.com|购物|京东网页版"
    "拼多多|https://www.pinduoduo.com|购物|拼多多网页版"
    "12306|https://www.12306.cn|出行|12306 铁路购票"
    "高德地图|https://www.amap.com|出行|高德地图网页版"
    "百度网盘|https://pan.baidu.com|工具|百度网盘网页版"
    "阿里云盘|https://www.aliyundrive.com|工具|阿里云盘网页版"
    "腾讯文档|https://docs.qq.com|办公|腾讯文档"
    "飞书文档|https://www.feishu.cn/drive|办公|飞书文档"
    "石墨文档|https://shimo.im|办公|石墨文档"
    "Notion|https://www.notion.so|办公|Notion 笔记"
    "GitHub|https://github.com|开发|GitHub"
    "Gmail|https://mail.google.com|办公|Gmail 邮箱"
    "Outlook|https://outlook.live.com|办公|Outlook 邮箱"
    "YouTube|https://www.youtube.com|媒体|YouTube"
    "Twitter/X|https://twitter.com|社交|Twitter/X"
)

# ============================================================
# 创建 PWA 启动脚本和桌面快捷方式
# ============================================================
info "创建 PWA 桌面应用..."

SUCCESS=0
for pwa in "${PWAS[@]}"; do
    IFS='|' read -r name url category description <<< "$pwa"

    # 生成安全的文件名
    safe_name=$(echo "$name" | tr ' ' '_' | tr -cd '[:alnum:]_')
    script_path="$BIN_DIR/pwa-${safe_name}.sh"
    desktop_path="$APPLICATIONS_DIR/pwa-${safe_name}.desktop"

    # 创建启动脚本
    cat > "$script_path" <<SCRIPT
#!/usr/bin/env bash
# PWA: ${name}
exec ${BROWSER_CMD:-chromium} --app="${url}" --class="PWA-${safe_name}" --name="PWA-${safe_name}"
SCRIPT
    chmod +x "$script_path"

    # 创建桌面快捷方式
    cat > "$desktop_path" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${name}
Comment=${description}
Exec=${script_path}
Icon=applications-internet
Categories=${category};Network;
Keywords=pwa;webapp;${name};
StartupWMClass=PWA-${safe_name}
DESKTOP

    ((SUCCESS++))
done

ok "创建了 $SUCCESS 个 PWA 应用"

# ============================================================
# 自定义 PWA 创建工具
# ============================================================
info "创建自定义 PWA 工具..."

cat > "$BIN_DIR/create-pwa" <<'CREATEPWA'
#!/usr/bin/env bash
# 创建自定义 PWA 桌面应用
# 用法: create-pwa <名称> <URL> [分类]

if [ $# -lt 2 ]; then
    echo "用法: create-pwa <名称> <URL> [分类]"
    echo "示例: create-pwa 我的网站 https://example.com 工具"
    exit 1
fi

NAME="$1"
URL="$2"
CATEGORY="${3:-网络}"
SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_')
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
SCRIPT_PATH="$BIN_DIR/pwa-${SAFE_NAME}.sh"
DESKTOP_PATH="$APPS_DIR/pwa-${SAFE_NAME}.desktop"

# 确定浏览器
if command -v chromium &>/dev/null; then
    BROWSER="chromium"
elif command -v google-chrome &>/dev/null; then
    BROWSER="google-chrome"
else
    BROWSER="chromium"
fi

mkdir -p "$BIN_DIR" "$APPS_DIR"

cat > "$SCRIPT_PATH" <<SCRIPT
#!/usr/bin/env bash
exec ${BROWSER} --app="${URL}" --class="PWA-${SAFE_NAME}" --name="PWA-${SAFE_NAME}"
SCRIPT
chmod +x "$SCRIPT_PATH"

cat > "$DESKTOP_PATH" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${NAME}
Comment=${URL}
Exec=${SCRIPT_PATH}
Icon=applications-internet
Categories=${CATEGORY};Network;
Keywords=pwa;webapp;
StartupWMClass=PWA-${SAFE_NAME}
DESKTOP

echo "✓ PWA 创建成功: $NAME"
echo "  启动脚本: $SCRIPT_PATH"
echo "  桌面文件: $DESKTOP_PATH"
echo "  可在应用菜单中找到 '$NAME'"
CREATEPWA
chmod +x "$BIN_DIR/create-pwa"

ok "自定义 PWA 工具已创建: $BIN_DIR/create-pwa"

# ============================================================
# 完成
# ============================================================
echo ""
info "=========================================="
info "  PWA 兼容层设置完成"
info "=========================================="
echo ""
info "已创建的 PWA 应用可以在应用菜单中找到，或通过命令行运行:"
info "  ~/.local/bin/pwa-<名称>.sh"
echo ""
info "创建自定义 PWA:"
info "  create-pwa <名称> <URL> [分类]"
info "  示例: create-pwa 我的网站 https://example.com 工具"
echo ""
info "注意:"
info "  - PWA 本质是浏览器窗口，功能取决于网页版支持程度"
info "  - 部分网站（如微信网页版）功能受限，推荐使用原生客户端"
info "  - PWA 不会保存独立的 Cookie（与浏览器共享）"
echo ""
ok "PWA 兼容层就绪！"

exit 0
