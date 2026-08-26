# CNomarchy 手机号认证服务

> 手机号作为唯一身份入口的后端服务
> 技术栈: Python 3.11+ / FastAPI / SQLite(可升级PostgreSQL) / JWT / 阿里云短信

## 功能

- 手机号 + 短信验证码登录/注册
- JWT Token 认证（Access + Refresh）
- 设备管理（绑定/解绑/列表/远程注销）
- 配置云同步（基于 Git，每个用户一个私有仓库）
- 换手机号
- Token 用量统计（AI Agent 计费基础）

## 快速开始

```bash
# 安装依赖
pip install -r requirements.txt

# 配置环境变量（复制模板）
cp .env.example .env
# 编辑 .env，填入阿里云短信密钥等

# 初始化数据库
python -c "from database import init_db; init_db()"

# 启动服务（开发模式）
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# 生产模式
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

## API 文档

启动后访问: http://localhost:8000/docs

## 核心 API

| 端点 | 方法 | 功能 | 认证 |
|---|---|---|---|
| /api/auth/send-code | POST | 发送短信验证码 | 否 |
| /api/auth/verify-code | POST | 验证验证码，返回 Token | 否 |
| /api/auth/refresh | POST | 刷新 Access Token | Refresh Token |
| /api/user/profile | GET | 获取用户信息 | Access Token |
| /api/user/devices | GET | 设备列表 | Access Token |
| /api/user/devices | POST | 绑定新设备 | Access Token |
| /api/user/devices/{id} | DELETE | 解绑设备 | Access Token |
| /api/user/change-phone | POST | 换手机号 | Access Token |
| /api/sync/config | GET | 拉取配置 | Access Token |
| /api/sync/config | POST | 推送配置 | Access Token |
| /api/agent/usage | GET | AI Token 用量 | Access Token |
| /api/agent/usage | POST | 记录 Token 用量 | Access Token |

## 配置说明

见 `.env.example`，主要配置项：

- `DATABASE_URL`: 数据库连接（默认 SQLite）
- `JWT_SECRET`: JWT 签名密钥（生产环境必须修改）
- `SMS_PROVIDER`: 短信服务商（aliyun/tencent/mock）
- `ALIYUN_ACCESS_KEY_ID`: 阿里云 AccessKey
- `ALIYUN_ACCESS_KEY_SECRET`: 阿里云 AccessKey Secret
- `ALIYUN_SIGN_NAME`: 短信签名
- `ALIYUN_TEMPLATE_CODE`: 短信模板代码
- `GIT_SYNC_DIR`: 配置同步 Git 仓库目录
- `VERIFICATION_CODE_TTL`: 验证码有效期（秒，默认 300）
- `ACCESS_TOKEN_EXPIRE_MINUTES`: Access Token 有效期（默认 60）
- `REFRESH_TOKEN_EXPIRE_DAYS`: Refresh Token 有效期（默认 90）
