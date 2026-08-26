# CNomarchy 架构设计

## 一、整体架构

```
┌──────────────────────────────────────────────────────────────┐
│                        用户交互层                               │
│  Quickshell 桌面 │ 系统级 Agent 入口 │ 插件市场 │ 设置中心    │
├──────────────────────────────────────────────────────────────┤
│                      中国化定制层                               │
│  中文输入法(Fcitx5) │ 中文字体 │ 国产AI模型Provider │ 国内镜像源 │
├──────────────────────────────────────────────────────────────┤
│                    手机号身份 & 云服务层                        │
│  短信认证 │ 扫码登录 │ 配置云同步(Git) │ 设备管理 │ Token计费  │
├──────────────────────────────────────────────────────────────┤
│                      五层兼容架构                               │
│  L1 原生Linux │ L2 Waydroid │ L3 Wine/Proton │ L4 PWA │ L5 云桌面│
├──────────────────────────────────────────────────────────────┤
│                    Omarchy 底座（Fork）                        │
│  Arch Linux │ Hyprland(Wayland) │ Quickshell │ Agent Harness │
└──────────────────────────────────────────────────────────────┘
```

## 二、ISO 构建架构

基于 Arch Linux 官方的 `archiso` 工具构建。

```
archiso profile
    │
    ├── profiledef.sh          ← 构建参数（架构、引导方式、压缩格式）
    ├── packages.x86_64        ← 预装包列表
    ├── pacman.conf            ← 软件源（Arch 国内镜像 + Omarchy 源）
    │
    └── airootfs/              ← 构建时注入到系统根目录的文件
        ├── customize.sh       ← 构建后执行的定制脚本（最核心）
        ├── etc/               ← 系统配置（locale、时区、服务）
        └── home/              ← 默认用户家目录配置
```

### 构建阶段

1. **基础系统安装** — archiso 按 packages.x86_64 安装所有包
2. **定制执行** — 运行 airootfs/customize.sh：本地化、用户创建、桌面配置部署、服务启用、Flatpak 初始化、Waydroid 依赖、AI Provider 配置
3. **引导镜像生成** — 生成可引导 ISO（UEFI + BIOS 双引导）

## 三、桌面环境架构

### 显示服务器：Wayland（不提供 X11 回退）

原因：Hyprland 是 Wayland-only；Waydroid 要求 Wayland；Omarchy 也是 Wayland。

### 组件

| 组件 | 软件 |
|---|---|
| 窗口管理器 | Hyprland |
| 桌面外壳 | Quickshell（状态栏/启动器/菜单/通知/锁屏一体化） |
| 终端 | Alacritty / WezTerm |
| 编辑器 | Neovim（预装）+ VS Code（Flatpak） |
| 文件管理器 | Nautilus / Thunar |
| 浏览器 | Chromium（预装）+ Firefox（可选） |

### 配置原则

所有桌面配置在 `~/.config/` 下，全部是纯文本文件，Agent 可直接读写。这是"系统即 Harness"的核心。

## 四、AI Agent 架构

### Agent Harness（复用 Omarchy 框架）

- 系统级入口：快捷键唤起，独立应用运行
- 多模型支持：可切换默认 Agent
- 权限系统：pkexec/polkit，敏感操作前显示具体命令请求授权
- 工具集：文件读写、命令执行、系统配置修改、包管理、插件安装
- 状态感知：当前窗口、系统状态、剪贴板、选中文字
- 反馈闭环：执行命令后读取输出，根据结果调整

### 国产模型 Provider

统一接口：`chat(messages, tools)`, `stream_chat()`, `get_usage()`

已规划：DeepSeek、通义千问 Qwen、豆包 Doubao、智谱 GLM、本地 Ollama、Claude/GPT/Gemini（海外）

### 插件系统

- 插件 = Git 仓库 + Lua/QML 脚本 + manifest.json
- Agent 可根据用户需求当场编写插件
- 插件市场：社区分享，一键安装

## 五、手机号身份架构

### 认证流程

```
输入手机号 → 服务端发短信验证码 → 输入验证码 → 验证通过 → 签发JWT
→ 客户端保存Token → 拉取用户配置(Git) → 应用到本地
```

### 身份服务 API

| 端点 | 功能 |
|---|---|
| POST /api/auth/send-code | 发送短信验证码 |
| POST /api/auth/verify-code | 验证验证码，返回 JWT |
| POST /api/auth/refresh | 刷新 Token |
| GET /api/user/profile | 获取用户信息 |
| GET/POST/DELETE /api/user/devices | 设备管理 |
| POST /api/user/change-phone | 换手机号 |

### 配置云同步

- 每个手机号对应一个私有 Git 仓库
- 内容：`.config/` 下所有桌面配置、Agent 配置、已安装插件列表、Flatpak 应用列表
- 登录时 pull，本地变更时自动 commit & push
- 为什么用 Git：配置是文本，Git 天然适合版本管理和冲突解决，Agent 也能理解 Git

### 设备管理

- 一个手机号可绑定多台设备
- 每台设备唯一 ID（基于硬件信息）
- 新设备首次登录需短信二次确认
- 信任设备 90 天免验证（可配置）

## 六、五层兼容架构

| 层 | 技术 | 覆盖 | 体验 |
|---|---|---|---|
| L1 原生 Linux | Flatpak + 官方源 | 微信/QQ/钉钉/飞书/WPS/浏览器/开发工具 | 最佳 |
| L2 安卓子系统 | Waydroid | 抖音/小红书/银行App/手游 | 好（接近原生） |
| L3 Windows 兼容 | Bottles(Wine) + Proton | 普通Windows软件/Steam游戏 | 中 |
| L4 Web/PWA | Chromium App 模式 | 网页版服务/后台系统/视频 | 好 |
| L5 云桌面 | RDP/Sunlight | 网银/税务/行业专用软件 | 取决于网络 |

**关键设计**：系统内置"软件安装器"，用户搜索软件名时自动按 L1→L2→L3→L4→L5 优先级推荐最优方案，一键执行。用户不需要知道底层技术。

## 七、软件源架构

```
pacman.conf
├── [core][extra][multilib]  ← Arch 官方源，国内镜像（清华TUNA/中科大USTC）
├── [omarchy]                 ← Omarchy 官方源（Quickshell 等专有包）
├── [cnomarchy]               ← 本项目自定义源（中国化脚本、主题、元包）
└── AUR via paru              ← AUR 包（用户可选）

Flatpak
└── flathub（国内镜像：清华TUNA）
```

## 八、安全架构

- 默认防火墙：ufw 启用
- Agent 权限：pkexec/polkit 管控
- 沙箱：Flatpak 沙箱、Waydroid 容器隔离、Wine 前缀隔离
- 传输加密：HTTPS、Git over HTTPS with token
- 可选全盘加密
- 隐私：默认不收集用户数据
