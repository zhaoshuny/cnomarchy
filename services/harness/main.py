"""
CNomarchy AI Agent Harness - REST API 主应用
提供系统状态读取和控制的 REST API 接口，供 AI Agent 调用

这是对标 Omarchy 的核心创新：把操作系统做成 AI Agent 可读可写的 Harness
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import os
import secrets

from system_reader import SystemReader
from system_writer import SystemWriter

# ============================================================
# 配置
# ============================================================
API_TOKEN = os.environ.get("CNOMARCHY_HARNESS_TOKEN", secrets.token_hex(32))
DRY_RUN = os.environ.get("CNOMARCHY_DRY_RUN", "false").lower() == "true"

# ============================================================
# 初始化
# ============================================================
app = FastAPI(
    title="CNomarchy AI Agent Harness API",
    description="把操作系统做成 AI Agent 可读可写的 Harness - 对标 Omarchy 核心创新",
    version="0.1.0",
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

reader = SystemReader()
writer = SystemWriter(dry_run=DRY_RUN)


# ============================================================
# 认证依赖
# ============================================================
async def verify_token(authorization: Optional[str] = Header(None)):
    """验证 API Token"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="缺少认证 Token")
    token = authorization.split(" ", 1)[1]
    if token != API_TOKEN:
        raise HTTPException(status_code=403, detail="无效的 Token")
    return True


# ============================================================
# 请求/响应模型
# ============================================================
class CommandRequest(BaseModel):
    command: str = Field(..., description="要执行的命令")
    timeout: int = Field(60, description="超时时间（秒）", ge=1, le=300)


class FileWriteRequest(BaseModel):
    path: str = Field(..., description="文件路径")
    content: str = Field(..., description="文件内容")


class PackageRequest(BaseModel):
    package: str = Field(..., description="软件包名")


class ServiceRequest(BaseModel):
    service: str = Field(..., description="服务名")


# ============================================================
# 系统信息读取接口（GET）
# ============================================================
@app.get("/", tags=["系统"])
async def root():
    """API 根路径，返回基本信息"""
    return {
        "name": "CNomarchy AI Agent Harness",
        "version": "0.1.0",
        "description": "把操作系统做成 AI Agent 可读可写的 Harness",
        "endpoints": {
            "system": "/api/v1/system",
            "cpu": "/api/v1/system/cpu",
            "memory": "/api/v1/system/memory",
            "disk": "/api/v1/system/disk",
            "network": "/api/v1/system/network",
            "processes": "/api/v1/system/processes",
            "services": "/api/v1/system/services",
            "packages": "/api/v1/system/packages",
        },
        "token_set": API_TOKEN != secrets.token_hex(32),
    }


@app.get("/api/v1/system", tags=["系统信息"])
async def get_system_info():
    """获取所有系统信息（汇总）"""
    return reader.get_all()


@app.get("/api/v1/system/os", tags=["系统信息"])
async def get_os_info():
    """获取操作系统信息"""
    return reader.get_os()


@app.get("/api/v1/system/cpu", tags=["系统信息"])
async def get_cpu_info():
    """获取 CPU 信息"""
    return reader.get_cpu()


@app.get("/api/v1/system/memory", tags=["系统信息"])
async def get_memory_info():
    """获取内存信息"""
    return reader.get_memory()


@app.get("/api/v1/system/disk", tags=["系统信息"])
async def get_disk_info():
    """获取磁盘信息"""
    return reader.get_disk()


@app.get("/api/v1/system/network", tags=["系统信息"])
async def get_network_info():
    """获取网络信息"""
    return reader.get_network()


@app.get("/api/v1/system/processes", tags=["系统信息"])
async def get_processes(limit: int = 20):
    """获取进程列表（按 CPU 使用率排序）"""
    return reader.get_processes(limit=limit)


@app.get("/api/v1/system/services", tags=["系统信息"])
async def get_services():
    """获取正在运行的服务列表"""
    return reader.get_services()


@app.get("/api/v1/system/uptime", tags=["系统信息"])
async def get_uptime():
    """获取系统运行时间"""
    return reader.get_uptime()


@app.get("/api/v1/system/load", tags=["系统信息"])
async def get_load():
    """获取系统负载"""
    return reader.get_load()


@app.get("/api/v1/system/packages", tags=["系统信息"])
async def get_packages(limit: int = 50):
    """获取已安装的软件包列表"""
    return reader.get_installed_packages(limit=limit)


@app.get("/api/v1/system/packages/search", tags=["系统信息"])
async def search_packages(keyword: str):
    """搜索软件包"""
    return reader.search_packages(keyword)


# ============================================================
# 系统控制接口（POST，需要认证）
# ============================================================
@app.post("/api/v1/control/command", tags=["系统控制"])
async def execute_command(req: CommandRequest, auth: bool = Depends(verify_token)):
    """执行命令（仅限允许列表中的命令）"""
    return writer.execute_command(req.command, timeout=req.timeout)


@app.post("/api/v1/control/package/install", tags=["系统控制"])
async def install_package(req: PackageRequest, auth: bool = Depends(verify_token)):
    """安装软件包"""
    return writer.install_package(req.package)


@app.post("/api/v1/control/package/remove", tags=["系统控制"])
async def remove_package(req: PackageRequest, auth: bool = Depends(verify_token)):
    """卸载软件包"""
    return writer.remove_package(req.package)


@app.post("/api/v1/control/system/update", tags=["系统控制"])
async def update_system(auth: bool = Depends(verify_token)):
    """更新系统"""
    return writer.update_system()


@app.post("/api/v1/control/service/start", tags=["系统控制"])
async def start_service(req: ServiceRequest, auth: bool = Depends(verify_token)):
    """启动服务"""
    return writer.start_service(req.service)


@app.post("/api/v1/control/service/stop", tags=["系统控制"])
async def stop_service(req: ServiceRequest, auth: bool = Depends(verify_token)):
    """停止服务"""
    return writer.stop_service(req.service)


@app.post("/api/v1/control/service/enable", tags=["系统控制"])
async def enable_service(req: ServiceRequest, auth: bool = Depends(verify_token)):
    """启用服务（开机自启）"""
    return writer.enable_service(req.service)


@app.post("/api/v1/control/service/disable", tags=["系统控制"])
async def disable_service(req: ServiceRequest, auth: bool = Depends(verify_token)):
    """禁用服务"""
    return writer.disable_service(req.service)


@app.get("/api/v1/control/service/logs", tags=["系统控制"])
async def get_service_logs(service: str, lines: int = 50, auth: bool = Depends(verify_token)):
    """获取服务日志"""
    return writer.get_service_logs(service, lines=lines)


@app.get("/api/v1/control/file/read", tags=["文件操作"])
async def read_file(path: str, auth: bool = Depends(verify_token)):
    """读取文件内容"""
    return writer.read_file(path)


@app.post("/api/v1/control/file/write", tags=["文件操作"])
async def write_file(req: FileWriteRequest, auth: bool = Depends(verify_token)):
    """写入文件内容"""
    return writer.write_file(req.path, req.content)


@app.post("/api/v1/control/system/reboot", tags=["系统控制"])
async def reboot_system(auth: bool = Depends(verify_token)):
    """重启系统"""
    return writer.reboot()


@app.post("/api/v1/control/system/shutdown", tags=["系统控制"])
async def shutdown_system(auth: bool = Depends(verify_token)):
    """关机"""
    return writer.shutdown()


# ============================================================
# 启动信息
# ============================================================
@app.on_event("startup")
async def startup_event():
    """启动时打印 Token"""
    print("=" * 60)
    print("  CNomarchy AI Agent Harness API 启动")
    print("=" * 60)
    print(f"  API Token: {API_TOKEN}")
    print(f"  API 文档: http://localhost:8000/docs")
    print(f"  干运行模式: {DRY_RUN}")
    print("=" * 60)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
