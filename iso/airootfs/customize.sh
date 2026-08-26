#!/usr/bin/env bash
# CNomarchy 构建定制脚本 (最小稳定版)
# 在 archiso chroot 环境中执行
# 原则：只做确定能成功的事，不确定的放到首次启动脚本

set -e

echo "=========================================="
echo "  CNomarchy customize.sh 开始"
echo "=========================================="

# ============================================================
# 1. 系统基础配置
# ============================================================
echo "[1/10] 系统基础配置..."

# 主机名
echo "cnomarchy" > /etc/hostname

# 时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc --utc || true

# Locale
cat > /etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
ko_KR.UTF-8 UTF-8
EOF
locale-gen

cat > /etc/locale.conf <<'EOF'
LANG=en_US.UTF-8
LC_CTYPE=zh_CN.UTF-8
LC_MESSAGES=en_US.UTF-8
EOF

cat > /etc/vconsole.conf <<'EOF'
KEYMAP=us
FONT=Lat2-Terminus16
EOF

# Pacman 镜像（国内源）
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch
Server = https://mirrors.hit.edu.cn/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf

# ============================================================
# 2. 创建用户
# ============================================================
echo "[2/10] 创建用户..."

DEFAULT_USER="cnomarchy"
useradd -m -G wheel,storage,power,network,video,audio,optical,uucp,input,lp,adm -s /bin/zsh "$DEFAULT_USER" || true
passwd -d "$DEFAULT_USER" || true
passwd -d root || true

# sudo 配置（wheel 组无密码，Live 环境）
cat > /etc/sudoers.d/cnomarchy <<'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
Defaults !tty_tickets
EOF
chmod 0440 /etc/sudoers.d/cnomarchy

# ============================================================
# 3. 自动登录 + 启动 Hyprland
# ============================================================
echo "[3/10] 配置自动登录..."

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $DEFAULT_USER --noclear %I \$TERM
Type=idle
EOF

# 用户登录后自动启动 Hyprland
cat > "/home/$DEFAULT_USER/.zprofile" <<'ZPROFILE'
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
ZPROFILE
chown "$DEFAULT_USER:$DEFAULT_USER" "/home/$DEFAULT_USER/.zprofile"

# ============================================================
# 4. 启用服务
# ============================================================
echo "[4/10] 启用系统服务..."

systemctl enable NetworkManager || true
systemctl enable systemd-resolved || true
systemctl enable bluetooth || true
systemctl enable cups || true
systemctl enable systemd-timesyncd || true
systemctl enable ufw || true
systemctl enable power-profiles-daemon || true
systemctl enable avahi-daemon || true
systemctl enable fstrim.timer || true

# ============================================================
# 5. 中文输入法环境变量
# ============================================================
echo "[5/10] 配置中文输入法环境变量..."

cat > /etc/environment <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
LANG=en_US.UTF-8
LC_CTYPE=zh_CN.UTF-8
EDITOR=nvim
VISUAL=nvim
EOF

# ============================================================
# 6. 部署桌面配置
# ============================================================
echo "[6/10] 部署桌面配置..."

USER_HOME="/home/$DEFAULT_USER"
CONFIG_DIR="$USER_HOME/.config"

mkdir -p "$CONFIG_DIR"/{hypr,fcitx5,fontconfig,alacritty,nvim,waybar,rofi}
mkdir -p "$USER_HOME"/{Pictures,Downloads,Documents,.local/bin,.local/share/applications}

# Hyprland 配置
cat > "$CONFIG_DIR/hypr/hyprland.conf" <<'HYPRCONF'
monitor = , preferred, auto, 1

input {
    kb_layout = us
    touchpad {
        natural_scroll = yes
        tap-to-click = yes
        two-finger-tap = right-click
    }
    follow_mouse = 1
    accel_profile = adaptive
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faff)
    col.inactive_border = rgba(444444ff)
    layout = dwindle
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 8
        passes = 4
    }
    drop_shadow = yes
}

animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

$mainMod = SUPER

bind = $mainMod, Return, exec, alacritty
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, B, exec, chromium
bind = $mainMod, Space, togglefloating
bind = $mainMod, F, fullscreen
bind = $mainMod SHIFT, Space, exec, rofi -show drun
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

exec-once = fcitx5 &
exec-once = nm-applet &
exec-once = blueman-applet &
exec-once = waybar &
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
exec-once = dunst &
exec-once = hyprpaper &
exec-once = copyq &
exec-once = swayidle -w timeout 300 'hyprlock' &

source = ~/.config/hypr/user.conf
HYPRCONF

# Waybar 配置（简单版）
mkdir -p "$CONFIG_DIR/waybar"
cat > "$CONFIG_DIR/waybar/config" <<'WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["network", "pulseaudio", "battery", "tray"],
    "hyprland/workspaces": {
        "format": "{name}",
        "show-icons": false
    },
    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y-%m-%d}</big>\n<tt>{:%H:%M:%S}</tt>"
    },
    "network": {
        "format": "{ifname}",
        "format-wifi": "📶 {essid} ({signalStrength}%)",
        "format-ethernet": "🌐 {ifname}",
        "format-disconnected": "⚠️ 断开"
    },
    "pulseaudio": {
        "format": "🔊 {volume}%",
        "format-muted": "🔇 静音",
        "scroll-step": 5
    },
    "battery": {
        "format": "🔋 {capacity}% {time}",
        "format-charging": "⚡ {capacity}% {time}",
        "format-full": "🔋 已满",
        "format-icons": ["", "", "", "", ""]
    },
    "tray": {
        "icon-size": 18,
        "spacing": 8
    }
}
WAYBAR

cat > "$CONFIG_DIR/waybar/style.css" <<'CSS'
* {
    font-family: "Noto Sans CJK SC", "JetBrains Mono", sans-serif;
    font-size: 13px;
    color: #ebdbb2;
}
window#waybar {
    background: rgba(40, 40, 40, 0.9);
    border-bottom: 2px solid #458588;
}
#workspaces button {
    padding: 0 8px;
    background: transparent;
    border: none;
}
#workspaces button.active {
    background: #458588;
    color: #282828;
}
#clock, #network, #pulseaudio, #battery, #tray, #window {
    padding: 0 10px;
}
#battery.warning { color: #fabd2f; }
#battery.critical { color: #fb4934; }
CSS

# Alacritty 配置
cat > "$CONFIG_DIR/alacritty/alacritty.toml" <<'ALACRITTY'
[font]
size = 13
[font.normal]
family = "JetBrains Mono"
style = "Regular"

[window]
padding = { x = 8, y = 8 }
decorations = "none"
opacity = 0.95

[cursor]
style = { shape = "Block", blinking = "On" }

[scrolling]
history = 10000

[colors.primary]
background = "0x282828"
foreground = "0xebdbb2"

[colors.normal]
black = "0x282828"
red = "0xcc241d"
green = "0x98971a"
yellow = "0xd79921"
blue = "0x458588"
magenta = "0xb16286"
cyan = "0x689d6a"
white = "0xa89984"

[colors.bright]
black = "0x928374"
red = "0xfb4934"
green = "0xb8bb26"
yellow = "0xfabd2f"
blue = "0x83a598"
magenta = "0xd3869b"
cyan = "0x8ec07c"
white = "0xebdbb2"

[keyboard.bindings]
{ key = "C", mods = "Control|Shift", action = "Copy" }
{ key = "V", mods = "Control|Shift", action = "Paste" }
{ key = "Equals", mods = "Control", action = "IncreaseFontSize" }
{ key = "Minus", mods = "Control", action = "DecreaseFontSize" }
{ key = "0", mods = "Control", action = "ResetFontSize" }

[shell]
program = "/bin/zsh"
args = ["--login"]
ALACRITTY

# 字体配置
cat > "$CONFIG_DIR/fontconfig/fonts.conf" <<'FONTS'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="pattern">
        <test qual="any" name="family"><string>sans-serif</string></test>
        <edit name="family" mode="prepend" binding="strong">
            <string>Noto Sans CJK SC</string>
            <string>WenQuanYi Zen Hei</string>
        </edit>
    </match>
    <match target="pattern">
        <test qual="any" name="family"><string>monospace</string></test>
        <edit name="family" mode="prepend" binding="strong">
            <string>JetBrains Mono</string>
            <string>Noto Sans Mono CJK SC</string>
        </edit>
    </match>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
</fontconfig>
FONTS

# Fcitx5 配置
cat > "$CONFIG_DIR/fcitx5/profile" <<'FCITX5'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=fcitx-keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
FCITX5

cat > "$CONFIG_DIR/fcitx5/config" <<'FCITX5CFG'
[Hotkey]
TriggerKeys=Control+space
AltTriggerKeys=Shift_L

[Behavior]
ShareInputState=No
PreeditEnabledByDefault=True

[Appearance]
Theme=default
Font=Sans 12
Vertical Candidate List=False
FCITX5CFG

# 修复所有权
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$CONFIG_DIR"
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/.local"
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/Pictures"
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/Downloads"
chown -R "$DEFAULT_USER:$DEFAULT_USER" "$USER_HOME/Documents"

# ============================================================
# 7. 防火墙
# ============================================================
echo "[7/10] 配置防火墙..."

ufw default deny incoming || true
ufw default allow outgoing || true
ufw allow 53317/tcp || true
ufw allow 53317/udp || true
ufw --force enable || true

# ============================================================
# 8. 首次启动脚本
# ============================================================
echo "[8/10] 配置首次启动脚本..."

mkdir -p /etc/cnomarchy
cat > /etc/cnomarchy/first-boot.sh <<'FIRSTBOOT'
#!/usr/bin/env bash
# CNomarchy 首次启动设置
set -e
LOG_FILE="/var/log/cnomarchy-first-boot.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] CNomarchy 首次启动设置开始"

# 添加 Flathub 国内镜像
if ! flatpak remotes 2>/dev/null | grep -q flathub; then
    echo "添加 Flathub 远程源..."
    flatpak remote-add --if-not-exists flathub \
        https://mirror.tuna.tsinghua.edu.cn/flathub/flathub.flatpakrepo 2>/dev/null || \
    flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

# 更新 Pacman 镜像
if command -v reflector &>/dev/null; then
    echo "更新 Pacman 镜像列表..."
    reflector --country China --age 12 --protocol https --sort rate \
        --save /etc/pacman.d/mirrorlist 2>/dev/null || true
fi

echo "CNomarchy 首次启动设置完成"
systemctl disable cnomarchy-first-boot.service
exit 0
FIRSTBOOT
chmod +x /etc/cnomarchy/first-boot.sh

cat > /etc/systemd/system/cnomarchy-first-boot.service <<'SERVICE'
[Unit]
Description=CNomarchy First Boot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/cnomarchy/first-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE
systemctl enable cnomarchy-first-boot.service || true

# ============================================================
# 9. 帮助命令
# ============================================================
echo "[9/10] 创建帮助命令..."

cat > /usr/local/bin/cnomarchy-help <<'HELP'
#!/usr/bin/env bash
cat <<'EOF'
╔══════════════════════════════════════════════════╗
║           CNomarchy 使用指南                       ║
╠══════════════════════════════════════════════════╣
║  快捷键:                                           ║
║    Super + Return       终端 (Alacritty)          ║
║    Super + B            浏览器 (Chromium)          ║
║    Super + E            文件管理器 (Thunar)        ║
║    Super + Shift+Space  应用启动器 (Rofi)          ║
║    Super + Q            关闭窗口                    ║
║    Super + F            全屏                        ║
║    Super + Space        浮动/平铺切换               ║
║    Super + 1-5          切换工作区                  ║
║    Ctrl + Space         中英文切换 (Fcitx5)        ║
║                                                    ║
║  中文输入法: 已预装 Fcitx5 拼音，Ctrl+Space 切换   ║
║  软件安装: sudo pacman -S <包名> 或 flatpak install║
║  安装到硬盘: sudo cnomarchy-install                 ║
╚══════════════════════════════════════════════════╝
EOF
HELP
chmod +x /usr/local/bin/cnomarchy-help

cat > /usr/local/bin/cnomarchy-install <<'INSTALL'
#!/usr/bin/env bash
echo "启动 CNomarchy 安装器 (archinstall)..."
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行: sudo cnomarchy-install"
    exit 1
fi
archinstall
INSTALL
chmod +x /usr/local/bin/cnomarchy-install

# ============================================================
# 10. 清理
# ============================================================
echo "[10/10] 清理..."

pacman -Scc --noconfirm || true
chown -R "$DEFAULT_USER:$DEFAULT_USER" "/home/$DEFAULT_USER"

# 复制配置到 /etc/skel（新用户模板）
mkdir -p /etc/skel/.config
cp -r "$CONFIG_DIR/hypr" /etc/skel/.config/ 2>/dev/null || true
cp -r "$CONFIG_DIR/fcitx5" /etc/skel/.config/ 2>/dev/null || true
cp -r "$CONFIG_DIR/alacritty" /etc/skel/.config/ 2>/dev/null || true
cp -r "$CONFIG_DIR/waybar" /etc/skel/.config/ 2>/dev/null || true
cp -r "$CONFIG_DIR/fontconfig" /etc/skel/.config/ 2>/dev/null || true

# 生成 initramfs
mkinitcpio -P || true

echo "=========================================="
echo "  CNomarchy customize.sh 完成"
echo "=========================================="
