"""
CNomarchy 认证服务 - Pydantic 请求/响应模型
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime
import re


def validate_phone(v: str) -> str:
    """验证中国大陆手机号格式"""
    v = v.strip()
    if not re.match(r"^1[3-9]\d{9}$", v):
        raise ValueError("手机号格式不正确，请输入11位中国大陆手机号")
    return v


# ============================================================
# 认证相关
# ============================================================
class SendCodeRequest(BaseModel):
    """发送验证码请求"""
    phone: str = Field(..., description="手机号")
    purpose: str = Field("login", description="用途: login/change_phone/new_device")

    @field_validator("phone")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)

    @field_validator("purpose")
    @classmethod
    def check_purpose(cls, v):
        if v not in ("login", "change_phone", "new_device"):
            raise ValueError("purpose 必须是 login/change_phone/new_device")
        return v


class SendCodeResponse(BaseModel):
    """发送验证码响应"""
    success: bool
    message: str
    # 开发模式下返回验证码（生产环境不返回）
    debug_code: Optional[str] = None
    expires_in: int = Field(..., description="验证码有效期（秒）")


class VerifyCodeRequest(BaseModel):
    """验证验证码请求"""
    phone: str = Field(..., description="手机号")
    code: str = Field(..., description="验证码")
    purpose: str = Field("login", description="用途")
    # 设备信息（登录时传入）
    device_id: Optional[str] = Field(None, description="设备唯一ID")
    device_name: Optional[str] = Field(None, description="设备名称")
    device_type: Optional[str] = Field("desktop", description="设备类型")
    os_info: Optional[str] = Field(None, description="操作系统信息")
    hardware_info: Optional[str] = Field(None, description="硬件信息")

    @field_validator("phone")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)


class TokenResponse(BaseModel):
    """Token 响应"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(..., description="Access Token 有效期（秒）")
    user_id: int
    phone: str
    display_name: str
    is_new_user: bool = False
    # 是否需要设备验证（新设备）
    require_device_verification: bool = False


class RefreshTokenRequest(BaseModel):
    """刷新 Token 请求"""
    refresh_token: str


class ChangePhoneRequest(BaseModel):
    """换手机号请求"""
    new_phone: str = Field(..., description="新手机号")
    new_phone_code: str = Field(..., description="新手机号验证码")
    old_phone_code: Optional[str] = Field(None, description="旧手机号验证码（可选，用于二次确认）")

    @field_validator("new_phone")
    @classmethod
    def check_phone(cls, v):
        return validate_phone(v)


# ============================================================
# 用户相关
# ============================================================
class UserProfile(BaseModel):
    """用户信息"""
    id: int
    phone: str
    display_name: str
    avatar_url: str
    status: str
    ai_token_balance: float
    created_at: datetime
    last_login_at: Optional[datetime]


class UpdateProfileRequest(BaseModel):
    """更新用户信息"""
    display_name: Optional[str] = Field(None, max_length=100)
    avatar_url: Optional[str] = Field(None, max_length=500)


# ============================================================
# 设备相关
# ============================================================
class DeviceInfo(BaseModel):
    """设备信息"""
    id: int
    device_id: str
    name: str
    device_type: str
    os_info: str
    is_trusted: bool
    trusted_until: Optional[datetime]
    last_active_at: datetime
    created_at: datetime


class DeviceListResponse(BaseModel):
    """设备列表响应"""
    devices: List[DeviceInfo]
    total: int
    max_allowed: int


class BindDeviceRequest(BaseModel):
    """绑定设备请求"""
    device_id: str = Field(..., description="设备唯一ID")
    name: Optional[str] = Field("未知设备", description="设备名称")
    device_type: Optional[str] = Field("desktop", description="设备类型")
    os_info: Optional[str] = Field("", description="操作系统信息")
    hardware_info: Optional[str] = Field("", description="硬件信息")
    verification_code: Optional[str] = Field(None, description="短信验证码（新设备需要）")


# ============================================================
# 配置同步相关
# ============================================================
class SyncConfigRequest(BaseModel):
    """推送配置请求"""
    # 配置内容（JSON 格式的配置文件集合）
    configs: dict = Field(..., description="配置文件内容，key为文件路径，value为内容")
    commit_message: Optional[str] = Field("sync config", description="提交信息")


class SyncConfigResponse(BaseModel):
    """拉取配置响应"""
    configs: dict
    last_commit: str
    last_commit_time: datetime


# ============================================================
# AI Agent 用量相关
# ============================================================
class AgentUsageRecord(BaseModel):
    """Agent 用量记录"""
    id: int
    model: str
    input_tokens: int
    output_tokens: int
    cost: float
    session_id: str
    created_at: datetime


class RecordUsageRequest(BaseModel):
    """记录用量请求"""
    model: str
    input_tokens: int = 0
    output_tokens: int = 0
    cost: float = 0.0
    session_id: Optional[str] = ""


class UsageSummary(BaseModel):
    """用量汇总"""
    total_input_tokens: int
    total_output_tokens: int
    total_cost: float
    total_requests: int
    period_start: datetime
    period_end: datetime
    balance: float


# ============================================================
# 通用响应
# ============================================================
class ApiResponse(BaseModel):
    """通用 API 响应"""
    success: bool
    message: str
    data: Optional[dict] = None


class ErrorResponse(BaseModel):
    """错误响应"""
    detail: str
    code: Optional[str] = None
