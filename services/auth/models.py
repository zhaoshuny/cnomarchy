"""
CNomarchy 认证服务 - 数据库模型
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base


class User(Base):
    """用户表（手机号为唯一标识）"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(20), unique=True, index=True, nullable=False)
    # 显示名（用户可自定义，默认手机号）
    display_name = Column(String(100), default="")
    # 头像 URL
    avatar_url = Column(String(500), default="")
    # 账户状态: active / disabled
    status = Column(String(20), default="active")
    # AI Token 余额（用于计费）
    ai_token_balance = Column(Float, default=0.0)
    # 创建时间
    created_at = Column(DateTime, default=datetime.utcnow)
    # 最后登录时间
    last_login_at = Column(DateTime, nullable=True)
    # 最后登录 IP
    last_login_ip = Column(String(50), default="")

    # 关联
    devices = relationship("Device", back_populates="user", cascade="all, delete-orphan")
    verification_codes = relationship("VerificationCode", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    agent_usage = relationship("AgentUsage", back_populates="user", cascade="all, delete-orphan")


class Device(Base):
    """设备表"""
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    # 设备唯一 ID（基于硬件信息生成）
    device_id = Column(String(200), unique=True, index=True, nullable=False)
    # 设备名称（用户可自定义）
    name = Column(String(100), default="未知设备")
    # 设备类型: desktop / laptop / vm / other
    device_type = Column(String(20), default="desktop")
    # 操作系统信息
    os_info = Column(String(500), default="")
    # 硬件信息（CPU、内存等摘要）
    hardware_info = Column(String(1000), default="")
    # 是否信任（信任设备免短信验证）
    is_trusted = Column(Boolean, default=False)
    # 信任到期时间
    trusted_until = Column(DateTime, nullable=True)
    # 最后活跃时间
    last_active_at = Column(DateTime, default=datetime.utcnow)
    # 创建时间
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="devices")


class VerificationCode(Base):
    """短信验证码表"""
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    phone = Column(String(20), index=True, nullable=False)
    code = Column(String(10), nullable=False)
    # 用途: login / change_phone / new_device
    purpose = Column(String(20), default="login")
    # 过期时间
    expires_at = Column(DateTime, nullable=False)
    # 是否已使用
    is_used = Column(Boolean, default=False)
    # 使用时间
    used_at = Column(DateTime, nullable=True)
    # 发送 IP
    send_ip = Column(String(50), default="")
    # 创建时间
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="verification_codes")


class RefreshToken(Base):
    """刷新令牌表"""
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    device_id = Column(Integer, ForeignKey("devices.id"), nullable=True)
    # 刷新令牌（哈希存储）
    token_hash = Column(String(500), unique=True, nullable=False)
    # 过期时间
    expires_at = Column(DateTime, nullable=False)
    # 是否已撤销
    is_revoked = Column(Boolean, default=False)
    # 撤销时间
    revoked_at = Column(DateTime, nullable=True)
    # 创建 IP
    created_ip = Column(String(50), default="")
    # 创建时间
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="refresh_tokens")


class AgentUsage(Base):
    """AI Agent Token 用量记录表"""
    __tablename__ = "agent_usage"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    # 使用的模型
    model = Column(String(100), nullable=False)
    # 输入 Token 数
    input_tokens = Column(Integer, default=0)
    # 输出 Token 数
    output_tokens = Column(Integer, default=0)
    # 费用（元）
    cost = Column(Float, default=0.0)
    # 会话 ID
    session_id = Column(String(200), default="")
    # 创建时间
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="agent_usage")


class PhoneChangeLog(Base):
    """手机号变更日志"""
    __tablename__ = "phone_change_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    old_phone = Column(String(20), nullable=False)
    new_phone = Column(String(20), nullable=False)
    # 变更 IP
    ip_address = Column(String(50), default="")
    # 变更时间
    created_at = Column(DateTime, default=datetime.utcnow)
