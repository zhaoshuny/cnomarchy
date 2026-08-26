"""
CNomarchy 认证服务 - 配置管理
"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """应用配置，从环境变量或 .env 文件读取"""

    # 数据库
    database_url: str = "sqlite:///./cnomarchy_auth.db"

    # JWT
    jwt_secret: str = "change-me-to-a-random-secret-key-at-least-32-chars"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 90

    # 短信验证码
    sms_provider: str = "mock"  # aliyun / tencent / mock
    verification_code_ttl: int = 300  # 5分钟
    verification_code_length: int = 6
    sms_send_interval: int = 60  # 1分钟
    sms_daily_limit: int = 10

    # 阿里云短信
    aliyun_access_key_id: str = ""
    aliyun_access_key_secret: str = ""
    aliyun_sign_name: str = "CNomarchy"
    aliyun_template_code: str = ""
    aliyun_endpoint: str = "dysmsapi.aliyuncs.com"

    # 腾讯云短信
    tencent_sdk_app_id: str = ""
    tencent_secret_id: str = ""
    tencent_secret_key: str = ""
    tencent_sign_name: str = "CNomarchy"
    tencent_template_id: str = ""

    # 配置云同步
    git_sync_dir: str = "./git-repos"
    git_author_name: str = "CNomarchy Bot"
    git_author_email: str = "bot@cnomarchy.local"

    # 设备管理
    max_devices_per_user: int = 10
    require_sms_for_new_device: bool = True

    # 服务
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    cors_origins: str = "*"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
