# CNomarchy 构建指南

## 前置要求

### 硬件
- CPU: x86_64（Intel/AMD），至少 4 核
- 内存: 至少 8GB（推荐 16GB）
- 磁盘: 至少 50GB 可用空间
- 网络: 稳定的互联网连接（需要下载大量包）

### 软件
- 操作系统: Arch Linux（推荐）或 Manjaro / EndeavourOS
- 权限: sudo 权限
- 已安装: git, curl, bash

## 构建步骤

### 1. 克隆项目

```bash
git clone <your-repo-url> cnomarchy
cd cnomarchy
```

### 2. 搭建构建环境

```bash
sudo bash scripts/setup-build-env.sh
```

这个脚本会安装:
- archiso（Arch 官方 ISO 构建工具）
- squashfs-tools, libisoburn, xorriso（ISO 生成工具）
- qemu-desktop, edk2-ovmf（虚拟机测试）
- 其他构建依赖

### 3. （可选）确认 Omarchy 软件源

编辑 `iso/pacman.conf`，确认 `[omarchy]` 段的 Server 地址正确。

地址需要从 Omarchy 官方 GitHub 确认: https://github.com/basecamp/omarchy

如果 Omarchy 源不可用，可以:
1. 注释掉 `[omarchy]` 段
2. 在 `iso/packages.x86_64` 中注释掉 `quickshell`、`omarchy-*` 等包
3. 系统将使用基础 Hyprland + waybar（功能完整但缺少 Omarchy 的一体化桌面外壳）

### 4. 构建 ISO

```bash
sudo bash scripts/build-iso.sh
```

构建过程:
1. 检查依赖和磁盘空间
2. 检查 Omarchy 源可用性
3. 清理旧的工作目录
4. 调用 `mkarchiso` 构建 ISO
5. 计算 SHA256 校验和

**预计时间**: 15-60 分钟（取决于网络速度和硬件性能）

**产物**:
- `out/cnomarchy-YYYY.MM.DD-x86_64.iso` — ISO 镜像
- `out/cnomarchy-YYYY.MM.DD-x86_64.iso.sha256` — 校验和

### 5. 测试 ISO

#### 方法 A: QEMU 虚拟机（推荐）

```bash
bash scripts/test-in-qemu.sh
```

这会自动:
- 找到最新的 ISO
- 配置 KVM 加速（如果可用）
- 创建 32GB 虚拟磁盘
- 启动 QEMU 虚拟机

默认配置: 半核 CPU / 半内存 / virtio 显卡 / UEFI 引导

#### 方法 B: 写入 U 盘

```bash
# 替换 /dev/sdX 为你的 U 盘设备名
sudo dd if=out/cnomarchy-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

#### 方法 C: Ventoy

安装 Ventoy 到 U 盘，然后直接复制 ISO 文件到 U 盘即可。

### 6. 安装到硬盘

1. 从 ISO 启动（Live 环境）
2. 默认用户: `cnomarchy`（无密码）
3. 运行安装器:
   ```bash
   sudo cnomarchy-install
   ```
4. 按 archinstall 提示完成安装（语言、磁盘、用户、引导等）
5. 安装完成后重启，从硬盘启动

## 构建配置说明

### ISO Profile 结构

```
iso/
├── profiledef.sh       # 构建参数（ISO 名称、压缩格式、引导方式）
├── packages.x86_64     # 预装软件包列表
├── pacman.conf          # 软件源配置
├── airootfs/
│   └── customize.sh     # 构建后定制脚本（最核心）
├── efiboot/             # UEFI 引导配置
└── syslinux/            # BIOS 引导配置
```

### customize.sh 做了什么

1. 设置主机名、时区（Asia/Shanghai）、中文 locale
2. 配置国内 Pacman 镜像源（清华 TUNA / 中科大 USTC）
3. 创建默认用户 `cnomarchy`（wheel 组，无密码 sudo）
4. 配置 tty1 自动登录 + 登录后自动启动 Hyprland
5. 启用系统服务（NetworkManager、蓝牙、CUPS、防火墙等）
6. 设置 Fcitx5 中文输入法环境变量
7. 部署 Hyprland 基础配置
8. 配置首次启动脚本（添加 Flathub 国内镜像、更新 Pacman 镜像）
9. 配置防火墙规则
10. 创建帮助命令 `cnomarchy-help` 和安装命令 `cnomarchy-install`

### 软件包分类

`packages.x86_64` 中的包按功能分组:
- 基础系统（内核、固件、引导）
- 网络（NetworkManager、VPN、防火墙）
- 音频（PipeWire）
- 蓝牙
- 打印（CUPS、HPLIP）
- Wayland + Hyprland
- Quickshell（Omarchy 桌面外壳）
- 终端 + Shell
- 编辑器 + 开发工具
- 浏览器
- 文件管理器
- 中文输入法（Fcitx5）
- 中文字体
- 办公软件
- 媒体工具
- 安全工具
- Flatpak
- Waydroid 依赖
- Wine + Steam

## 常见问题

### Q: 构建失败，提示 "quickshell" 包找不到
A: Omarchy 软件源地址可能不正确或不可用。检查 `iso/pacman.conf` 中的 `[omarchy]` 段，或临时注释掉相关包。

### Q: 构建很慢
A: 首次构建需要下载所有包（约 3-5GB），取决于网络速度。使用国内镜像源可以大幅提速。

### Q: QEMU 中很卡
A: 确保 KVM 加速可用（CPU 支持虚拟化且 BIOS 中启用）。脚本会自动检测并使用 KVM。

### Q: 中文输入法不能用
A: 检查环境变量 `GTK_IM_MODULE=fcitx` 和 `QT_IM_MODULE=fcitx` 是否设置。系统已默认配置，Flatpak 应用可能需要额外授权。

### Q: 如何添加自定义包？
A: 编辑 `iso/packages.x86_64`，添加包名即可。AUR 包需要在 `customize.sh` 中通过 `paru` 安装。

### Q: 如何修改桌面配置？
A: 编辑 `desktop/` 目录下的配置文件，然后在 `customize.sh` 中添加复制命令将配置部署到用户家目录。

## 认证服务部署

认证服务（手机号登录后端）是独立的 Python 服务，需要单独部署。

详见: `services/auth/README.md`

快速部署:
```bash
cd services/auth
pip install -r requirements.txt
cp .env.example .env
# 编辑 .env，配置短信服务商和密钥
python -c "from database import init_db; init_db()"
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 下一步

- [ ] 在虚拟机中充分测试
- [ ] 在真实硬件上测试（特别是 NVIDIA 显卡和笔记本）
- [ ] 部署认证服务到云服务器
- [ ] 配置域名和 HTTPS
- [ ] 申请短信服务（阿里云/腾讯云）
- [ ] 小范围公测，收集反馈
