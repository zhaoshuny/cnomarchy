# CNomarchy Flatpak 常用软件清单

> 推荐通过 `bash compat/flatpak/setup.sh` 一键安装。
> 手动安装: `flatpak install flathub <包名>`

## 社交沟通

| 软件 | Flatpak 包名 | 状态 | 备注 |
|---|---|---|---|
| 微信 | com.tencent.WeChat | ✅ 可用 | 腾讯官方 Linux 版 |
| QQ | com.qq.QQ | ✅ 可用 | NT QQ |
| 腾讯会议 | com.tencent.wemeet | ✅ 可用 | |
| 飞书 | cn.feishu.Feishu | ✅ 可用 | |
| 钉钉 | 待确认 | ⚠️ | 有官方 Linux 版(.deb)，Flatpak 包名待确认 |
| 企业微信 | 待确认 | ⚠️ | 有官方 Linux 版 |
| Telegram | org.telegram.desktop | ✅ | |
| Discord | com.discordapp.Discord | ✅ | |
| Signal | org.signal.Signal | ✅ | |

## 办公

| 软件 | Flatpak 包名 | 状态 | 备注 |
|---|---|---|---|
| WPS Office | cn.wps.wps_365 | ✅ 可用 | 对 MS Office 兼容性最好 |
| OnlyOffice | org.onlyoffice.desktopeditors | ✅ | 开源，协作强 |
| LibreOffice | app.libreoffice.LibreOffice | ✅ | 开源办公套件 |
| 雷鸟邮件 | org.mozilla.Thunderbird | ✅ | |
| Obsidian | md.obsidian.Obsidian | ✅ | 笔记 |
| Logseq | org.logseq.Logseq | ✅ | 笔记 |

## 浏览器

| 软件 | Flatpak 包名 | 状态 |
|---|---|---|
| Chrome | com.google.Chrome | ✅ |
| Firefox | org.mozilla.firefox | ✅ |
| Edge | com.microsoft.Edge | ✅ |
| Chromium | 官方源 pacman -S chromium | ✅ |

## 开发工具

| 软件 | Flatpak 包名 | 状态 |
|---|---|---|
| VS Code | com.visualstudio.code | ✅ |
| IDEA Community | com.jetbrains.IntelliJ-IDEA-Community | ✅ |
| Podman Desktop | io.podman_desktop.PodmanDesktop | ✅ |
| GitKraken | com.axosoft.GitKraken | ✅ |
| Postman | com.getpostman.Postman | ✅ |

## 媒体

| 软件 | Flatpak 包名 | 状态 |
|---|---|---|
| VLC | org.videolan.VLC | ✅ |
| Spotify | com.spotify.Client | ✅ |
| OBS Studio | com.obsproject.Studio | ✅ |
| HandBrake | fr.handbrake.ghb | ✅ |
| GIMP | org.gimp.GIMP | ✅ |
| Inkscape | org.inkscape.Inkscape | ✅ |
| Blender | org.blender.Blender | ✅ |
| Krita | org.kde.krita | ✅ |
| Audacity | org.audacityteam.Audacity | ✅ |
| Kdenlive | org.kde.kdenlive | ✅ |

## 安全与工具

| 软件 | Flatpak 包名 | 状态 |
|---|---|---|
| Bitwarden | com.bitwarden.desktop | ✅ |
| KeePassXC | org.keepassxc.KeePassXC | ✅ |
| Flatseal | com.github.tchx84.Flatseal | ✅ 权限管理 |
| Warehouse | io.github.flattool.Warehouse | ✅ Flatpak管理 |
| Extension Manager | com.mattjakeman.ExtensionManager | ✅ GNOME扩展 |

## 注意事项

1. **包名可能变化**：Flathub 上的包名由维护者决定，可能随版本变化。安装前可用 `flatpak search <关键词>` 确认。
2. **国内访问**：Flathub 官方源在国内访问较慢，建议使用清华 TUNA 镜像。
3. **权限问题**：Flatpak 应用默认沙箱化，访问本地文件需要额外授权。使用 Flatseal 图形化管理权限。
4. **输入法**：Flatpak 应用使用 Fcitx5 需要确保 `GTK_IM_MODULE=fcitx` 和 `QT_IM_MODULE=fcitx` 环境变量已设置（系统已默认配置）。
5. **Wayland 支持**：大部分 Flatpak 应用支持 Wayland，少数老应用需要 X11（系统已预装 XWayland）。
