"""
CNomarchy 认证服务 - JWT 认证与工具函数
"""
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from config import settings
from database import get_db
from models import User, RefreshToken, Device

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/verify-code", auto_error=False)


def hash_token(token: str) -> str:
    """哈希 Token（用于存储）"""
    return hashlib.sha256(token.encode()).hexdigest()


def create_access_token(user_id: int, phone: str, device_id: Optional[int] = None) -> tuple[str, int]:
    """创建 Access Token
    Returns:
        (token, expires_in_seconds)
    """
    expires_in = settings.access_token_expire_minutes * 60
    expire = datetime.utcnow() + timedelta(seconds=expires_in)
    payload = {
        "sub": str(user_id),
        "phone": phone,
        "type": "access",
        "device_id": device_id,
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": secrets.token_hex(16),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_in


def create_refresh_token(user_id: int, phone: str, device_id: Optional[int] = None) -> tuple[str, datetime]:
    """创建 Refresh Token
    Returns:
        (token, expires_at)
    """
    expires_at = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)
    payload = {
        "sub": str(user_id),
        "phone": phone,
        "type": "refresh",
        "device_id": device_id,
        "exp": expires_at,
        "iat": datetime.utcnow(),
        "jti": secrets.token_hex(16),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_at


def decode_token(token: str) -> Optional[dict]:
    """解码 JWT Token"""
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload
    except JWTError:
        return None


def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """获取当前登录用户（FastAPI 依赖）"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无法验证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token:
        raise credentials_exception

    payload = decode_token(token)
    if payload is None:
        raise credentials_exception

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token 类型错误，需要 Access Token",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise credentials_exception

    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被禁用",
        )

    return user


def get_current_device(
    token: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> Optional[Device]:
    """获取当前请求的设备（如果 Token 中包含 device_id）"""
    if not token:
        return None

    payload = decode_token(token)
    if payload is None:
        return None

    device_id = payload.get("device_id")
    if device_id is None:
        return None

    return db.query(Device).filter(Device.id == int(device_id)).first()


def generate_device_id(hardware_info: str = "") -> str:
    """生成设备唯一 ID（基于硬件信息）"""
    if hardware_info:
        return hashlib.sha256(hardware_info.encode()).hexdigest()[:32]
    # 如果没有硬件信息，生成随机 ID（但这样每次都会变，不推荐）
    return secrets.token_hex(16)
