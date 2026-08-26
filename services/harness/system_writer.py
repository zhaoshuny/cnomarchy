"""
CNomarchy AI Agent Harness - 系统控制写入模块
提供软件安装、配置修改、服务管理、命令执行等系统控制接口
所有操作都需要权限验证和安全检查
"""

import os
import subprocess
import shutil
from typing import Dict, Any, List, Optional, Tuple
from pathlib import Path


class SystemWriter:
    """系统控制器"""

    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.allowed_commands = {
            "pacman", "systemctl", "journalctl", "ls", "cat", "grep",
            "find", "df", "free", "top", "ps", "ip", "nmcli",
            "flatpak", "waydroid", "wine", "winetricks",
        }

    def _run_command(
        self, cmd: str, timeout: int = 60, requires_root: bool = False
    ) -> Tuple[int, str, str]:
        """执行命令（带安全检查）"""
        # 安全检查：禁止危险命令
        dangerous_patterns = ["rm -rf /", "mkfs", "dd if=", ":(){:|:&};:", "chmod 777 /"]
        for pattern in dangerous_patterns:
            if pattern in cmd:
                return -1, "", f"安全拦截：禁止执行危险命令 '{pattern}'"

        # 检查是否需要 root 权限
        if requires_root and os.geteuid() != 0:
            cmd = f"sudo {cmd}"

        if self.dry_run:
            return 0, f"[DRY RUN] Would execute: {cmd}", ""

        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", f"命令执行超时（{timeout}秒）"
        except Exception as e:
            return -1, "", str(e)

    def install_package(self, package: str) -> Dict[str, Any]:
        """安装软件包"""
        if not package or not package.replace("-", "").replace("_", "").isalnum():
            return {"success": False, "error": "无效的包名"}

        cmd = f"pacman -S --noconfirm {package}"
        code, stdout, stderr = self._run_command(cmd, timeout=300, requires_root=True)

        return {
            "success": code == 0,
            "package": package,
            "output": stdout[-2000:] if len(stdout) > 2000 else stdout,
            "error": stderr[-1000:] if stderr else None,
        }

    def remove_package(self, package: str) -> Dict[str, Any]:
        """卸载软件包"""
        if not package or not package.replace("-", "").replace("_", "").isalnum():
            return {"success": False, "error": "无效的包名"}

        cmd = f"pacman -Rns --noconfirm {package}"
        code, stdout, stderr = self._run_command(cmd, timeout=120, requires_root=True)

        return {
            "success": code == 0,
            "package": package,
            "output": stdout[-2000:] if len(stdout) > 2000 else stdout,
            "error": stderr[-1000:] if stderr else None,
        }

    def update_system(self) -> Dict[str, Any]:
        """更新系统"""
        cmd = "pacman -Syu --noconfirm"
        code, stdout, stderr = self._run_command(cmd, timeout=600, requires_root=True)

        return {
            "success": code == 0,
            "output": stdout[-3000:] if len(stdout) > 3000 else stdout,
            "error": stderr[-1000:] if stderr else None,
        }

    def start_service(self, service: str) -> Dict[str, Any]:
        """启动服务"""
        if not service.endswith(".service"):
            service = f"{service}.service"

        cmd = f"systemctl start {service}"
        code, stdout, stderr = self._run_command(cmd, timeout=30, requires_root=True)

        return {
            "success": code == 0,
            "service": service,
            "error": stderr if stderr else None,
        }

    def stop_service(self, service: str) -> Dict[str, Any]:
        """停止服务"""
        if not service.endswith(".service"):
            service = f"{service}.service"

        cmd = f"systemctl stop {service}"
        code, stdout, stderr = self._run_command(cmd, timeout=30, requires_root=True)

        return {
            "success": code == 0,
            "service": service,
            "error": stderr if stderr else None,
        }

    def enable_service(self, service: str) -> Dict[str, Any]:
        """启用服务（开机自启）"""
        if not service.endswith(".service"):
            service = f"{service}.service"

        cmd = f"systemctl enable {service}"
        code, stdout, stderr = self._run_command(cmd, timeout=30, requires_root=True)

        return {
            "success": code == 0,
            "service": service,
            "error": stderr if stderr else None,
        }

    def disable_service(self, service: str) -> Dict[str, Any]:
        """禁用服务"""
        if not service.endswith(".service"):
            service = f"{service}.service"

        cmd = f"systemctl disable {service}"
        code, stdout, stderr = self._run_command(cmd, timeout=30, requires_root=True)

        return {
            "success": code == 0,
            "service": service,
            "error": stderr if stderr else None,
        }

    def get_service_logs(self, service: str, lines: int = 50) -> Dict[str, Any]:
        """获取服务日志"""
        if not service.endswith(".service"):
            service = f"{service}.service"

        cmd = f"journalctl -u {service} -n {lines} --no-pager"
        code, stdout, stderr = self._run_command(cmd, timeout=30)

        return {
            "success": code == 0,
            "service": service,
            "logs": stdout,
            "error": stderr if stderr else None,
        }

    def read_file(self, path: str) -> Dict[str, Any]:
        """读取文件内容"""
        # 安全检查：禁止读取敏感文件
        sensitive_paths = ["/etc/shadow", "/etc/gshadow", "/root/.ssh", "~/.ssh/id_rsa"]
        for sp in sensitive_paths:
            if os.path.expanduser(path).startswith(os.path.expanduser(sp)):
                return {"success": False, "error": "安全拦截：禁止读取敏感文件"}

        try:
            with open(os.path.expanduser(path), "r") as f:
                content = f.read()
            return {
                "success": True,
                "path": path,
                "content": content[:10000] if len(content) > 10000 else content,
                "truncated": len(content) > 10000,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def write_file(self, path: str, content: str) -> Dict[str, Any]:
        """写入文件内容"""
        # 安全检查：禁止写入系统关键目录
        protected_paths = ["/boot", "/etc/passwd", "/etc/shadow", "/bin", "/sbin", "/usr/bin"]
        for pp in protected_paths:
            if os.path.expanduser(path).startswith(pp):
                return {"success": False, "error": f"安全拦截：禁止写入受保护路径 '{pp}'"}

        try:
            full_path = os.path.expanduser(path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)
            return {
                "success": True,
                "path": path,
                "bytes_written": len(content),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def execute_command(self, cmd: str, timeout: int = 60) -> Dict[str, Any]:
        """执行任意命令（带安全检查）"""
        # 检查命令是否在允许列表中
        cmd_base = cmd.split()[0] if cmd.split() else ""
        if cmd_base not in self.allowed_commands and not cmd_base.startswith("./"):
            return {
                "success": False,
                "error": f"安全拦截：命令 '{cmd_base}' 不在允许列表中",
                "allowed_commands": list(self.allowed_commands),
            }

        code, stdout, stderr = self._run_command(cmd, timeout=timeout)

        return {
            "success": code == 0,
            "command": cmd,
            "exit_code": code,
            "stdout": stdout[-3000:] if len(stdout) > 3000 else stdout,
            "stderr": stderr[-1000:] if stderr else None,
        }

    def reboot(self) -> Dict[str, Any]:
        """重启系统"""
        cmd = "reboot"
        code, stdout, stderr = self._run_command(cmd, timeout=10, requires_root=True)
        return {"success": code == 0, "error": stderr if stderr else None}

    def shutdown(self) -> Dict[str, Any]:
        """关机"""
        cmd = "shutdown now"
        code, stdout, stderr = self._run_command(cmd, timeout=10, requires_root=True)
        return {"success": code == 0, "error": stderr if stderr else None}
