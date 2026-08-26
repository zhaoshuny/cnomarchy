# CNomarchy AI Agent Harness

> 把操作系统做成 AI Agent 可读可写的 Harness —— 对标 Omarchy 核心创新

## 概述

CNomarchy AI Agent Harness 是一个 REST API 服务，将 Linux 操作系统的状态和控制能力暴露给 AI Agent，使 AI 能够：

- **读取**：CPU、内存、磁盘、网络、进程、服务、软件包等系统状态
- **写入**：安装/卸载软件、管理服务、修改配置文件、执行命令等系统操作
- **控制**：重启、关机等系统级操作

## 架构

```
AI Agent (Claude/GPT/本地模型)
    │
    │  HTTP REST API (Bearer Token 认证)
    ▼
┌─────────────────────────────────┐
│  CNomarchy AI Agent Harness API │
│  (FastAPI + Uvicorn)            │
└─────────────────────────────────┘
    │
    ├──► SystemReader  (系统状态读取)
    │      - CPU / 内存 / 磁盘 / 网络
    │      - 进程 / 服务 / 软件包
    │      - 运行时间 / 系统负载
    │
    └──► SystemWriter  (系统控制写入)
           - 安装/卸载软件包
           - 启动/停止/启用/禁用服务
           - 读取/写入配置文件
           - 执行允许列表中的命令
           - 重启/关机
```

## 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 启动服务

```bash
# 默认启动（自动生成 Token）
python main.py

# 指定 Token
CNOMARCHY_HARNESS_TOKEN=your-secret-token python main.py

# 干运行模式（不实际执行修改操作）
CNOMARCHY_DRY_RUN=true python main.py
```

### 3. 访问 API 文档

打开浏览器访问：http://localhost:8000/docs

## API 接口

### 系统信息读取（无需认证）

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/system` | GET | 获取所有系统信息（汇总） |
| `/api/v1/system/os` | GET | 操作系统信息 |
| `/api/v1/system/cpu` | GET | CPU 信息 |
| `/api/v1/system/memory` | GET | 内存信息 |
| `/api/v1/system/disk` | GET | 磁盘信息 |
| `/api/v1/system/network` | GET | 网络信息 |
| `/api/v1/system/processes` | GET | 进程列表 |
| `/api/v1/system/services` | GET | 运行中的服务 |
| `/api/v1/system/uptime` | GET | 系统运行时间 |
| `/api/v1/system/load` | GET | 系统负载 |
| `/api/v1/system/packages` | GET | 已安装软件包 |
| `/api/v1/system/packages/search` | GET | 搜索软件包 |

### 系统控制写入（需要 Bearer Token 认证）

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/control/command` | POST | 执行命令（仅限允许列表） |
| `/api/v1/control/package/install` | POST | 安装软件包 |
| `/api/v1/control/package/remove` | POST | 卸载软件包 |
| `/api/v1/control/system/update` | POST | 更新系统 |
| `/api/v1/control/service/start` | POST | 启动服务 |
| `/api/v1/control/service/stop` | POST | 停止服务 |
| `/api/v1/control/service/enable` | POST | 启用服务（开机自启） |
| `/api/v1/control/service/disable` | POST | 禁用服务 |
| `/api/v1/control/service/logs` | GET | 获取服务日志 |
| `/api/v1/control/file/read` | GET | 读取文件内容 |
| `/api/v1/control/file/write` | POST | 写入文件内容 |
| `/api/v1/control/system/reboot` | POST | 重启系统 |
| `/api/v1/control/system/shutdown` | POST | 关机 |

## 使用示例

### 获取系统信息

```bash
curl http://localhost:8000/api/v1/system/cpu
```

### 安装软件包

```bash
curl -X POST http://localhost:8000/api/v1/control/package/install \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"package": "vim"}'
```

### 执行命令

```bash
curl -X POST http://localhost:8000/api/v1/control/command \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"command": "ls -la /home", "timeout": 30}'
```

## 安全机制

1. **Token 认证**：所有写入操作都需要 Bearer Token 认证
2. **命令白名单**：只允许执行预定义的安全命令列表
3. **敏感文件保护**：禁止读取 /etc/shadow、SSH 私钥等敏感文件
4. **受保护路径**：禁止写入 /boot、/etc/passwd 等系统关键路径
5. **危险命令拦截**：自动拦截 `rm -rf /`、`mkfs`、`dd` 等危险命令
6. **干运行模式**：支持 `DRY_RUN=true` 模式，只输出将要执行的操作而不实际执行

## 与 Omarchy 的对比

| 特性 | Omarchy | CNomarchy Harness |
|------|---------|-------------------|
| 全系统文本可配置 | ✅ | ✅ |
| AI Agent 可读 | ✅ | ✅ |
| AI Agent 可写 | ✅ | ✅ |
| REST API 接口 | 内部 | 公开 |
| 安全认证 | 内置 | Bearer Token |
| 命令白名单 | ✅ | ✅ |
| 干运行模式 | ✅ | ✅ |

## 系统服务配置

### systemd 服务

```ini
[Unit]
Description=CNomarchy AI Agent Harness
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cnomarchy/harness
Environment="CNOMARCHY_HARNESS_TOKEN=your-secret-token"
ExecStart=/opt/cnomarchy/harness/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 许可证

MIT License
