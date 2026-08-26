# CNomarchy — 中国版 AI 原生桌面操作系统

> 基于 Omarchy (Arch Linux + Hyprland + Quickshell) 的中国化发行版，手机号作为唯一身份入口，五层兼容架构解决软件生态问题。

## 这是什么

Omarchy 是 DHH（Ruby on Rails 之父）做的 Linux 发行版，核心创新是**把操作系统本身做成 AI Agent 可读可写的 Harness**——整个桌面环境（状态栏、启动器、菜单、通知、锁屏）在一个叫 Quickshell 的进程里，配置全部是 Lua 脚本，Agent 可以读配置、改文件、跑命令、写插件。

CNomarchy 在 Omarchy 基础上做三件事：

1. **中国化** — 中文输入法开箱即用、国内软件源镜像、国产 AI 模型接入（DeepSeek / 通义千问 / 豆包 / 智谱 GLM）、常用国产软件预装
2. **手机号唯一入口** — 没有用户名/邮箱/密码，手机号 + 短信验证码登录，配置云同步、多设备管理、AI Token 计费全部以手机号为 key
3. **五层兼容架构** — 原生 Linux → 安卓子系统(Waydroid) → Wine/Proton → PWA → 云桌面，系统性解决软件生态问题

## 技术栈

| 层 | 技术 | 说明 |
|---|---|---|
| 底座 | Arch Linux | 滚动更新，一切皆文件 |
| 窗口管理 | Hyprland | Wayland 平铺式窗口管理器 |
| 桌面外壳 | Quickshell | Omarchy 自研，QML/JS/Lua，全系统文本可配置 |
| AI Agent | 系统级 Agent Harness | 支持 DeepSeek/Qwen/豆包/GLM/Claude/GPT 等 |
| 兼容层 | Flatpak + Waydroid + Wine(Bottles) + PWA + 云桌面 | 五层兜底 |
| 身份服务 | Python FastAPI + SQLite/PostgreSQL | 手机号认证、配置同步、设备管理 |
| ISO 构建 | archiso | Arch 官方构建工具 |

## 快速开始

### 前置要求

- 一台 x86_64 的 Linux 机器（或虚拟机），至少 4 核 8G 内存，50G 磁盘
- 操作系统：Arch Linux 或任何能安装 archiso 的发行版
- 你需要能跑 shell 命令

### 构建 ISO

```bash
# 1. 克隆项目
git clone <your-repo-url> cnomarchy
cd cnomarchy

# 2. 搭建构建环境
sudo bash scripts/setup-build-env.sh

# 3. 构建 ISO
sudo bash scripts/build-iso.sh

# 4. 产物在 out/ 目录下
ls out/
```

### 测试

```bash
# 用 QEMU 测试 ISO
bash scripts/test-in-qemu.sh
```

## 项目结构

```
cnomarchy/
├── iso/                # ISO 构建配置（archiso profile）
│   ├── profiledef.sh   # 构建参数定义
│   ├── packages.x86_64 # 预装软件包列表
│   ├── pacman.conf     # 软件源配置（Arch 国内镜像 + Omarchy 源）
│   └── airootfs/       # 构建时执行的定制脚本
│       └── customize.sh
├── desktop/            # 桌面环境配置
│   ├── hypr/           # Hyprland 窗口管理器配置
│   ├── quickshell/     # Quickshell 桌面外壳配置
│   ├── fcitx5/         # 中文输入法配置
│   ├── fonts/          # 中文字体配置
│   └── theme/          # 主题
├── compat/             # 五层兼容层
│   ├── flatpak/        # Flatpak 配置 + 国内镜像 + 常用软件清单
│   ├── waydroid/       # 安卓子系统安装配置脚本
│   ├── wine/           # Wine/Bottles 配置 + 兼容性数据库
│   └── pwa/            # PWA 网站封装脚本
├── services/           # 后端云服务
│   ├── auth/           # 手机号认证服务（FastAPI）
│   └── sync/           # 配置云同步服务
├── scripts/            # 工具脚本
│   ├── build-iso.sh    # ISO 构建主脚本
│   ├── setup-build-env.sh # 构建环境搭建
│   └── test-in-qemu.sh # QEMU 测试
├── packages/           # 自定义 AUR 包（PKGBUILD）
├── docs/               # 文档
│   ├── architecture.md # 架构设计
│   ├── roadmap.md      # 开发路线图
│   └── build-guide.md  # 构建指南
└── assets/             # 图片、图标等资源
```

## 与 Omarchy 的关系

- Omarchy 是 MIT 协议开源项目（github.com/basecamp/omarchy），CNomarchy 合法 Fork 其配置和包
- 核心差异：中国化层 + 手机号身份体系 + 五层兼容架构
- 策略：尽量保持与 Omarchy 上游同步，最小化分叉，中国化部分作为独立层叠加

## 免责声明

这是一个一人公司 + AI 协作的开源项目，不提供任何担保。使用前请在虚拟机中充分测试。
