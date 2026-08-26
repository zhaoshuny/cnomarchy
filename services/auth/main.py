"""
CNomarchy 手机号认证服务 - 主应用
基于 FastAPI，提供手机号登录、设备管理、配置同步、AI用量统计等 API
"""
import os
import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func

from config import settings
from database import get_db, init_db
from models import User, Device, VerificationCode, RefreshToken, AgentUsage, PhoneChangeLog
from schemas import (
    SendCodeRequest, SendCodeResponse, VerifyCodeRequest, TokenResponse,
    RefreshTokenRequest, ChangePhoneRequest,
    UserProfile, UpdateProfileRequest,
    DeviceInfo, DeviceListResponse, BindDeviceRequest,
    SyncConfigRequest, SyncConfigResponse,
    RecordUsageRequest, AgentUsageRecord, UsageSummary,
    ApiResponse,
)
from sms import get_sms_service, generate_code
from auth_utils import (
    create_access_token, create_refresh_token, decode_token,
    get_current_user, get_current_device, hash_token, generate_device_id,
)

# 日志配置
logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("cnomarchy-auth")

# 创建 FastAPI 应用
app = FastAPI(
    title="CNomarchy 认证服务",
    description="手机号作为唯一身份入口的后端服务",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS 中间件
cors_origins = settings.cors_origins.split(",") if settings.cors_origins != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# 启动事件
# ============================================================
@app.on_event("startup")
async def startup_event():
    """应用启动时初始化"""
    init_db()
    # 确保 Git 同步目录存在
    os.makedirs(settings.git_sync_dir, exist_ok=True)
    logger.info("CNomarchy 认证服务启动完成")
    logger.info(f"短信服务商: {settings.sms_provider}")
    logger.info(f"数据库: {settings.database_url}")


# ============================================================
# 工具函数
# ============================================================
def get_client_ip(request: Request) -> str:
    """获取客户端 IP"""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else ""


def check_send_rate_limit(db: Session, phone: str, ip: str) -> tuple[bool, str]:
    """检查短信发送频率限制
    Returns:
        (是否允许, 原因)
    """
    now = datetime.utcnow()

    # 1. 同一手机号发送间隔
    recent = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.phone == phone,
            VerificationCode.created_at > now - timedelta(seconds=settings.sms_send_interval),
        )
        .first()
    )
    if recent:
        wait_seconds = settings.sms_send_interval - (now - recent.created_at).seconds
        return False, f"发送过于频繁，请等待 {wait_seconds} 秒后重试"

    # 2. 同一手机号每日上限
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_count = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.phone == phone,
            VerificationCode.created_at >= today_start,
        )
        .count()
    )
    if today_count >= settings.sms_daily_limit:
        return False, "今日验证码发送次数已达上限，请明天再试"

    return True, ""


def verify_code_logic(db: Session, phone: str, code: str, purpose: str) -> tuple[bool, str, Optional[VerificationCode]]:
    """验证验证码逻辑
    Returns:
        (是否有效, 原因, 验证码记录)
    """
    now = datetime.utcnow()

    record = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.phone == phone,
            VerificationCode.code == code,
            VerificationCode.purpose == purpose,
            VerificationCode.is_used == False,
            VerificationCode.expires_at > now,
        )
        .order_by(VerificationCode.created_at.desc())
        .first()
    )

    if not record:
        return False, "验证码错误或已过期", None

    return True, "", record


# ============================================================
# 认证 API
# ============================================================
@app.post("/api/auth/send-code", response_model=SendCodeResponse, tags=["认证"])
async def send_verification_code(
    request: Request,
    body: SendCodeRequest,
    db: Session = Depends(get_db),
):
    """发送短信验证码"""
    phone = body.phone
    purpose = body.purpose
    ip = get_client_ip(request)

    # 频率限制检查
    allowed, reason = check_send_rate_limit(db, phone, ip)
    if not allowed:
        raise HTTPException(status_code=429, detail=reason)

    # 生成验证码
    code = generate_code()

    # 发送短信
    sms_service = get_sms_service()
    success = sms_service.send_code(phone, code, purpose)

    if not success:
        raise HTTPException(status_code=500, detail="短信发送失败，请稍后重试")

    # 保存验证码记录
    expires_at = datetime.utcnow() + timedelta(seconds=settings.verification_code_ttl)
    vc = VerificationCode(
        phone=phone,
        code=code,
        purpose=purpose,
        expires_at=expires_at,
        send_ip=ip,
    )
    db.add(vc)
    db.commit()

    logger.info(f"验证码已发送: {phone}, 用途: {purpose}, IP: {ip}")

    return SendCodeResponse(
        success=True,
        message="验证码已发送",
        debug_code=code if settings.sms_provider == "mock" else None,
        expires_in=settings.verification_code_ttl,
    )


@app.post("/api/auth/verify-code", response_model=TokenResponse, tags=["认证"])
async def verify_code_and_login(
    request: Request,
    body: VerifyCodeRequest,
    db: Session = Depends(get_db),
):
    """验证验证码并登录/注册"""
    phone = body.phone
    code = body.code
    purpose = body.purpose
    ip = get_client_ip(request)

    # 验证验证码
    valid, reason, vc_record = verify_code_logic(db, phone, code, purpose)
    if not valid:
        raise HTTPException(status_code=400, detail=reason)

    # 标记验证码已使用
    vc_record.is_used = True
    vc_record.used_at = datetime.utcnow()

    # 查找或创建用户
    user = db.query(User).filter(User.phone == phone).first()
    is_new_user = False
    if not user:
        user = User(
            phone=phone,
            display_name=f"用户{phone[-4:]}",
            last_login_ip=ip,
        )
        db.add(user)
        db.flush()  # 获取 user.id
        is_new_user = True
        logger.info(f"新用户注册: {phone}")

    # 更新用户登录信息
    user.last_login_at = datetime.utcnow()
    user.last_login_ip = ip

    # 设备管理
    device_record = None
    require_device_verification = False

    if body.device_id:
        # 查找设备
        device_record = db.query(Device).filter(Device.device_id == body.device_id).first()

        if not device_record:
            # 新设备
            if settings.require_sms_for_new_device and purpose != "new_device":
                # 需要新设备验证（但本次验证码是 login 用途，需要额外验证）
                # 简化处理：首次登录的设备直接绑定，标记为未信任
                pass

            # 检查设备数量上限
            device_count = db.query(Device).filter(Device.user_id == user.id).count()
            if device_count >= settings.max_devices_per_user:
                raise HTTPException(
                    status_code=400,
                    detail=f"设备数量已达上限（{settings.max_devices_per_user}台），请先解绑旧设备",
                )

            device_record = Device(
                user_id=user.id,
                device_id=body.device_id,
                name=body.device_name or "未知设备",
                device_type=body.device_type or "desktop",
                os_info=body.os_info or "",
                hardware_info=body.hardware_info or "",
                is_trusted=False,
                last_active_at=datetime.utcnow(),
            )
            db.add(device_record)
            db.flush()
            require_device_verification = True
            logger.info(f"新设备绑定: user={user.id}, device={body.device_id}")
        else:
            # 已有设备，更新活跃时间
            device_record.last_active_at = datetime.utcnow()
            if device_record.user_id != user.id:
                # 设备属于其他用户，不允许
                raise HTTPException(status_code=400, detail="该设备已绑定其他账户")

    db.commit()

    # 生成 Token
    device_id_for_token = device_record.id if device_record else None
    access_token, expires_in = create_access_token(user.id, user.phone, device_id_for_token)
    refresh_token, refresh_expires_at = create_refresh_token(user.id, user.phone, device_id_for_token)

    # 保存 Refresh Token
    rt = RefreshToken(
        user_id=user.id,
        device_id=device_id_for_token,
        token_hash=hash_token(refresh_token),
        expires_at=refresh_expires_at,
        created_ip=ip,
    )
    db.add(rt)
    db.commit()

    logger.info(f"用户登录: {phone}, 新用户: {is_new_user}, IP: {ip}")

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        user_id=user.id,
        phone=user.phone,
        display_name=user.display_name,
        is_new_user=is_new_user,
        require_device_verification=require_device_verification,
    )


@app.post("/api/auth/refresh", response_model=TokenResponse, tags=["认证"])
async def refresh_token(
    request: Request,
    body: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    """刷新 Access Token"""
    payload = decode_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="无效的刷新令牌")

    # 检查 Token 是否被撤销
    token_hash = hash_token(body.refresh_token)
    rt = db.query(RefreshToken).filter(RefreshToken.token_hash == token_hash).first()
    if not rt or rt.is_revoked:
        raise HTTPException(status_code=401, detail="刷新令牌已被撤销")

    if rt.expires_at < datetime.utcnow():
        raise HTTPException(status_code=401, detail="刷新令牌已过期")

    user = db.query(User).filter(User.id == rt.user_id).first()
    if not user or user.status != "active":
        raise HTTPException(status_code=401, detail="用户不存在或已被禁用")

    # 撤销旧的 Refresh Token，生成新的（旋转机制）
    rt.is_revoked = True
    rt.revoked_at = datetime.utcnow()

    # 生成新 Token
    access_token, expires_in = create_access_token(user.id, user.phone, rt.device_id)
    new_refresh_token, refresh_expires_at = create_refresh_token(user.id, user.phone, rt.device_id)

    new_rt = RefreshToken(
        user_id=user.id,
        device_id=rt.device_id,
        token_hash=hash_token(new_refresh_token),
        expires_at=refresh_expires_at,
        created_ip=get_client_ip(request),
    )
    db.add(new_rt)
    db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=expires_in,
        user_id=user.id,
        phone=user.phone,
        display_name=user.display_name,
        is_new_user=False,
    )


@app.post("/api/auth/logout", response_model=ApiResponse, tags=["认证"])
async def logout(
    body: RefreshTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """退出登录（撤销 Refresh Token）"""
    token_hash = hash_token(body.refresh_token)
    rt = db.query(RefreshToken).filter(
        RefreshToken.token_hash == token_hash,
        RefreshToken.user_id == current_user.id,
    ).first()

    if rt:
        rt.is_revoked = True
        rt.revoked_at = datetime.utcnow()
        db.commit()

    return ApiResponse(success=True, message="已退出登录")


# ============================================================
# 用户 API
# ============================================================
@app.get("/api/user/profile", response_model=UserProfile, tags=["用户"])
async def get_profile(current_user: User = Depends(get_current_user)):
    """获取用户信息"""
    return UserProfile(
        id=current_user.id,
        phone=current_user.phone,
        display_name=current_user.display_name,
        avatar_url=current_user.avatar_url,
        status=current_user.status,
        ai_token_balance=current_user.ai_token_balance,
        created_at=current_user.created_at,
        last_login_at=current_user.last_login_at,
    )


@app.put("/api/user/profile", response_model=UserProfile, tags=["用户"])
async def update_profile(
    body: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """更新用户信息"""
    if body.display_name is not None:
        current_user.display_name = body.display_name
    if body.avatar_url is not None:
        current_user.avatar_url = body.avatar_url

    db.commit()
    db.refresh(current_user)

    return UserProfile(
        id=current_user.id,
        phone=current_user.phone,
        display_name=current_user.display_name,
        avatar_url=current_user.avatar_url,
        status=current_user.status,
        ai_token_balance=current_user.ai_token_balance,
        created_at=current_user.created_at,
        last_login_at=current_user.last_login_at,
    )


@app.post("/api/user/change-phone", response_model=ApiResponse, tags=["用户"])
async def change_phone(
    request: Request,
    body: ChangePhoneRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """换手机号"""
    new_phone = body.new_phone

    # 检查新手机号是否已被注册
    existing = db.query(User).filter(User.phone == new_phone).first()
    if existing:
        raise HTTPException(status_code=400, detail="该手机号已被注册")

    # 验证新手机号验证码
    valid, reason, vc_record = verify_code_logic(db, new_phone, body.new_phone_code, "change_phone")
    if not valid:
        raise HTTPException(status_code=400, detail=reason)

    # 记录变更日志
    log = PhoneChangeLog(
        user_id=current_user.id,
        old_phone=current_user.phone,
        new_phone=new_phone,
        ip_address=get_client_ip(request),
    )
    db.add(log)

    # 更新手机号
    old_phone = current_user.phone
    current_user.phone = new_phone
    vc_record.is_used = True
    vc_record.used_at = datetime.utcnow()

    # 撤销所有现有 Refresh Token（需要重新登录）
    db.query(RefreshToken).filter(
        RefreshToken.user_id == current_user.id,
        RefreshToken.is_revoked == False,
    ).update({"is_revoked": True, "revoked_at": datetime.utcnow()})

    db.commit()
    logger.info(f"用户换手机号: {old_phone} -> {new_phone}")

    return ApiResponse(success=True, message="手机号已更新，请使用新手机号重新登录")


# ============================================================
# 设备管理 API
# ============================================================
@app.get("/api/user/devices", response_model=DeviceListResponse, tags=["设备"])
async def list_devices(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取设备列表"""
    devices = (
        db.query(Device)
        .filter(Device.user_id == current_user.id)
        .order_by(Device.last_active_at.desc())
        .all()
    )

    return DeviceListResponse(
        devices=[
            DeviceInfo(
                id=d.id,
                device_id=d.device_id,
                name=d.name,
                device_type=d.device_type,
                os_info=d.os_info,
                is_trusted=d.is_trusted,
                trusted_until=d.trusted_until,
                last_active_at=d.last_active_at,
                created_at=d.created_at,
            )
            for d in devices
        ],
        total=len(devices),
        max_allowed=settings.max_devices_per_user,
    )


@app.post("/api/user/devices", response_model=ApiResponse, tags=["设备"])
async def bind_device(
    body: BindDeviceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """绑定新设备"""
    # 检查设备是否已存在
    existing = db.query(Device).filter(Device.device_id == body.device_id).first()
    if existing:
        if existing.user_id == current_user.id:
            return ApiResponse(success=True, message="设备已绑定", data={"device_id": existing.id})
        else:
            raise HTTPException(status_code=400, detail="该设备已绑定其他账户")

    # 检查设备数量
    count = db.query(Device).filter(Device.user_id == current_user.id).count()
    if count >= settings.max_devices_per_user:
        raise HTTPException(status_code=400, detail=f"设备数量已达上限（{settings.max_devices_per_user}台）")

    # 新设备需要短信验证
    if settings.require_sms_for_new_device and not body.verification_code:
        raise HTTPException(status_code=400, detail="新设备绑定需要短信验证码，请先调用 /api/auth/send-code (purpose=new_device)")

    if body.verification_code:
        valid, reason, vc = verify_code_logic(db, current_user.phone, body.verification_code, "new_device")
        if not valid:
            raise HTTPException(status_code=400, detail=reason)
        vc.is_used = True
        vc.used_at = datetime.utcnow()

    device = Device(
        user_id=current_user.id,
        device_id=body.device_id,
        name=body.name or "未知设备",
        device_type=body.device_type or "desktop",
        os_info=body.os_info or "",
        hardware_info=body.hardware_info or "",
        is_trusted=False,
    )
    db.add(device)
    db.commit()

    return ApiResponse(success=True, message="设备绑定成功", data={"device_id": device.id})


@app.delete("/api/user/devices/{device_id}", response_model=ApiResponse, tags=["设备"])
async def unbind_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """解绑设备"""
    device = db.query(Device).filter(
        Device.id == device_id,
        Device.user_id == current_user.id,
    ).first()

    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")

    # 撤销该设备的 Refresh Token
    db.query(RefreshToken).filter(
        RefreshToken.device_id == device.id,
        RefreshToken.is_revoked == False,
    ).update({"is_revoked": True, "revoked_at": datetime.utcnow()})

    db.delete(device)
    db.commit()

    return ApiResponse(success=True, message="设备已解绑")


# ============================================================
# 配置同步 API
# ============================================================
def get_user_repo_path(user_id: int) -> str:
    """获取用户配置 Git 仓库路径"""
    return os.path.join(settings.git_sync_dir, f"user-{user_id}")


@app.get("/api/sync/config", response_model=SyncConfigResponse, tags=["配置同步"])
async def pull_config(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """拉取用户配置"""
    try:
        from git import Repo, InvalidGitRepositoryError

        repo_path = get_user_repo_path(current_user.id)

        if not os.path.exists(repo_path):
            # 仓库不存在，返回空配置
            return SyncConfigResponse(
                configs={},
                last_commit="",
                last_commit_time=datetime.utcnow(),
            )

        repo = Repo(repo_path)
        # 读取所有跟踪的文件
        configs = {}
        for file_path in repo.git.ls_files().split("\n"):
            if file_path:
                full_path = os.path.join(repo_path, file_path)
                if os.path.isfile(full_path):
                    try:
                        with open(full_path, "r", encoding="utf-8") as f:
                            configs[file_path] = f.read()
                    except UnicodeDecodeError:
                        # 二进制文件跳过
                        pass

        last_commit = repo.head.commit.hexsha if repo.head.is_valid() else ""
        last_commit_time = repo.head.commit.committed_datetime if repo.head.is_valid() else datetime.utcnow()

        return SyncConfigResponse(
            configs=configs,
            last_commit=last_commit,
            last_commit_time=last_commit_time,
        )

    except Exception as e:
        logger.error(f"拉取配置失败: {e}")
        raise HTTPException(status_code=500, detail=f"拉取配置失败: {str(e)}")


@app.post("/api/sync/config", response_model=ApiResponse, tags=["配置同步"])
async def push_config(
    body: SyncConfigRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """推送用户配置"""
    try:
        from git import Repo

        repo_path = get_user_repo_path(current_user.id)
        os.makedirs(repo_path, exist_ok=True)

        # 初始化或打开仓库
        if not os.path.exists(os.path.join(repo_path, ".git")):
            repo = Repo.init(repo_path)
            # 配置 Git 用户
            with repo.config_writer() as git_config:
                git_config.set_value("user", "name", settings.git_author_name)
                git_config.set_value("user", "email", settings.git_author_email)
        else:
            repo = Repo(repo_path)

        # 写入配置文件
        for file_path, content in body.configs.items():
            # 防止路径穿越
            safe_path = os.path.normpath(file_path).lstrip("/\\")
            if safe_path.startswith(".."):
                continue

            full_path = os.path.join(repo_path, safe_path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w", encoding="utf-8") as f:
                f.write(content)

        # 提交
        repo.index.add("*")
        if repo.is_dirty(untracked_files=True):
            commit = repo.index.commit(body.commit_message or "sync config")
            commit_hash = commit.hexsha
        else:
            commit_hash = repo.head.commit.hexsha if repo.head.is_valid() else ""

        return ApiResponse(
            success=True,
            message="配置同步成功",
            data={"commit": commit_hash},
        )

    except Exception as e:
        logger.error(f"推送配置失败: {e}")
        raise HTTPException(status_code=500, detail=f"推送配置失败: {str(e)}")


# ============================================================
# AI Agent 用量 API
# ============================================================
@app.get("/api/agent/usage", response_model=UsageSummary, tags=["AI用量"])
async def get_usage_summary(
    period: str = "month",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取 AI Token 用量汇总"""
    now = datetime.utcnow()
    if period == "day":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "week":
        start = now - timedelta(days=7)
    else:  # month
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    records = db.query(AgentUsage).filter(
        AgentUsage.user_id == current_user.id,
        AgentUsage.created_at >= start,
    ).all()

    total_input = sum(r.input_tokens for r in records)
    total_output = sum(r.output_tokens for r in records)
    total_cost = sum(r.cost for r in records)

    return UsageSummary(
        total_input_tokens=total_input,
        total_output_tokens=total_output,
        total_cost=total_cost,
        total_requests=len(records),
        period_start=start,
        period_end=now,
        balance=current_user.ai_token_balance,
    )


@app.post("/api/agent/usage", response_model=ApiResponse, tags=["AI用量"])
async def record_usage(
    body: RecordUsageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """记录 AI Token 用量"""
    record = AgentUsage(
        user_id=current_user.id,
        model=body.model,
        input_tokens=body.input_tokens,
        output_tokens=body.output_tokens,
        cost=body.cost,
        session_id=body.session_id or "",
    )
    db.add(record)

    # 扣除余额
    if body.cost > 0:
        current_user.ai_token_balance = max(0, current_user.ai_token_balance - body.cost)

    db.commit()

    return ApiResponse(success=True, message="用量已记录")


# ============================================================
# 健康检查
# ============================================================
@app.get("/health", tags=["系统"])
async def health_check():
    """健康检查"""
    return {"status": "ok", "service": "cnomarchy-auth", "version": "1.0.0"}


@app.get("/", tags=["系统"])
async def root():
    """根路径"""
    return {
        "name": "CNomarchy 认证服务",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


# ============================================================
# 运行入口
# ============================================================
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        workers=1 if settings.debug else 4,
    )
