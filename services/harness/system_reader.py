"""
CNomarchy AI Agent Harness - 系统状态读取模块
提供 CPU、内存、磁盘、网络、进程、服务等系统信息的读取接口
"""

import os
import json
import subprocess
import platform
from typing import Dict, Any, List, Optional


class SystemReader:
    """系统状态读取器"""

    def __init__(self):
        self.os_info = self._get_os_info()

    def _run_command(self, cmd: str, timeout: int = 10) -> str:
        """执行 shell 命令并返回输出"""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=timeout
            )
            return result.stdout.strip()
        except Exception as e:
            return f"Error: {str(e)}"

    def _get_os_info(self) -> Dict[str, str]:
        """获取操作系统信息"""
        info = {
            "system": platform.system(),
            "node": platform.node(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
        }
        # 读取 /etc/os-release
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release") as f:
                for line in f:
                    if "=" in line:
                        key, value = line.strip().split("=", 1)
                        info[key.lower()] = value.strip('"')
        return info

    def get_all(self) -> Dict[str, Any]:
        """获取所有系统信息（汇总）"""
        return {
            "os": self.get_os(),
            "cpu": self.get_cpu(),
            "memory": self.get_memory(),
            "disk": self.get_disk(),
            "network": self.get_network(),
            "uptime": self.get_uptime(),
            "load": self.get_load(),
        }

    def get_os(self) -> Dict[str, str]:
        """获取操作系统信息"""
        return self.os_info

    def get_cpu(self) -> Dict[str, Any]:
        """获取 CPU 信息"""
        cpu_info = {
            "model": "",
            "cores": 0,
            "threads": 0,
            "usage_percent": 0.0,
            "frequency_mhz": 0.0,
        }

        # CPU 型号
        model = self._run_command("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs")
        if model and not model.startswith("Error"):
            cpu_info["model"] = model

        # 核心数和线程数
        cores = self._run_command("grep 'cpu cores' /proc/cpuinfo | head -1 | awk '{print $4}'")
        if cores and not cores.startswith("Error") and cores.isdigit():
            cpu_info["cores"] = int(cores)

        threads = self._run_command("nproc")
        if threads and not threads.startswith("Error") and threads.isdigit():
            cpu_info["threads"] = int(threads)

        # CPU 使用率（通过 top）
        usage = self._run_command("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d% -f1")
        if usage and not usage.startswith("Error"):
            try:
                cpu_info["usage_percent"] = float(usage)
            except ValueError:
                pass

        # CPU 频率
        freq = self._run_command("grep 'cpu MHz' /proc/cpuinfo | head -1 | awk '{print $4}'")
        if freq and not freq.startswith("Error"):
            try:
                cpu_info["frequency_mhz"] = float(freq)
            except ValueError:
                pass

        return cpu_info

    def get_memory(self) -> Dict[str, Any]:
        """获取内存信息"""
        mem_info = {
            "total_mb": 0,
            "used_mb": 0,
            "free_mb": 0,
            "available_mb": 0,
            "usage_percent": 0.0,
            "swap_total_mb": 0,
            "swap_used_mb": 0,
            "swap_free_mb": 0,
        }

        # 读取 /proc/meminfo
        if os.path.exists("/proc/meminfo"):
            with open("/proc/meminfo") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2:
                        key = parts[0].rstrip(":")
                        value = int(parts[1]) // 1024  # KB -> MB
                        if key == "MemTotal":
                            mem_info["total_mb"] = value
                        elif key == "MemFree":
                            mem_info["free_mb"] = value
                        elif key == "MemAvailable":
                            mem_info["available_mb"] = value
                        elif key == "SwapTotal":
                            mem_info["swap_total_mb"] = value
                        elif key == "SwapFree":
                            mem_info["swap_free_mb"] = value

        mem_info["used_mb"] = mem_info["total_mb"] - mem_info["free_mb"]
        mem_info["swap_used_mb"] = mem_info["swap_total_mb"] - mem_info["swap_free_mb"]

        if mem_info["total_mb"] > 0:
            mem_info["usage_percent"] = round(
                (mem_info["used_mb"] / mem_info["total_mb"]) * 100, 1
            )

        return mem_info

    def get_disk(self) -> List[Dict[str, Any]]:
        """获取磁盘信息"""
        disks = []
        output = self._run_command("df -h -x tmpfs -x devtmpfs -x overlay")
        if output and not output.startswith("Error"):
            lines = output.split("\n")[1:]  # 跳过表头
            for line in lines:
                parts = line.split()
                if len(parts) >= 6:
                    disks.append({
                        "filesystem": parts[0],
                        "size": parts[1],
                        "used": parts[2],
                        "available": parts[3],
                        "usage_percent": parts[4].rstrip("%"),
                        "mount_point": parts[5],
                    })
        return disks

    def get_network(self) -> Dict[str, Any]:
        """获取网络信息"""
        network = {
            "interfaces": [],
            "hostname": self.os_info.get("node", ""),
            "dns_servers": [],
        }

        # 网络接口
        output = self._run_command("ip -br addr")
        if output and not output.startswith("Error"):
            for line in output.split("\n"):
                parts = line.split()
                if len(parts) >= 2:
                    iface = {
                        "name": parts[0],
                        "state": parts[1],
                        "ip": parts[2] if len(parts) > 2 else "",
                    }
                    network["interfaces"].append(iface)

        # DNS 服务器
        if os.path.exists("/etc/resolv.conf"):
            with open("/etc/resolv.conf") as f:
                for line in f:
                    if line.startswith("nameserver"):
                        network["dns_servers"].append(line.split()[1])

        return network

    def get_processes(self, limit: int = 20) -> List[Dict[str, Any]]:
        """获取进程列表（按 CPU 使用率排序）"""
        processes = []
        output = self._run_command(f"ps aux --sort=-%cpu | head -{limit + 1}")
        if output and not output.startswith("Error"):
            lines = output.split("\n")[1:]  # 跳过表头
            for line in lines:
                parts = line.split(None, 10)
                if len(parts) >= 11:
                    processes.append({
                        "user": parts[0],
                        "pid": int(parts[1]),
                        "cpu_percent": float(parts[2]),
                        "mem_percent": float(parts[3]),
                        "vsz_kb": int(parts[4]),
                        "rss_kb": int(parts[5]),
                        "tty": parts[6],
                        "stat": parts[7],
                        "start": parts[8],
                        "time": parts[9],
                        "command": parts[10],
                    })
        return processes

    def get_services(self) -> List[Dict[str, Any]]:
        """获取 systemd 服务状态"""
        services = []
        output = self._run_command("systemctl list-units --type=service --state=running --no-pager --no-legend")
        if output and not output.startswith("Error"):
            for line in output.split("\n"):
                parts = line.split(None, 4)
                if len(parts) >= 4:
                    services.append({
                        "unit": parts[0],
                        "load": parts[1],
                        "active": parts[2],
                        "sub": parts[3],
                        "description": parts[4] if len(parts) > 4 else "",
                    })
        return services

    def get_uptime(self) -> Dict[str, Any]:
        """获取系统运行时间"""
        uptime_info = {
            "uptime_seconds": 0,
            "uptime_human": "",
            "boot_time": "",
        }

        if os.path.exists("/proc/uptime"):
            with open("/proc/uptime") as f:
                uptime_seconds = float(f.read().split()[0])
                uptime_info["uptime_seconds"] = int(uptime_seconds)

                # 转换为人类可读格式
                days = int(uptime_seconds // 86400)
                hours = int((uptime_seconds % 86400) // 3600)
                minutes = int((uptime_seconds % 3600) // 60)
                uptime_info["uptime_human"] = f"{days}天 {hours}小时 {minutes}分钟"

        # 启动时间
        boot_time = self._run_command("uptime -s")
        if boot_time and not boot_time.startswith("Error"):
            uptime_info["boot_time"] = boot_time

        return uptime_info

    def get_load(self) -> Dict[str, Any]:
        """获取系统负载"""
        load_info = {
            "load_1min": 0.0,
            "load_5min": 0.0,
            "load_15min": 0.0,
            "running_processes": 0,
            "total_processes": 0,
        }

        output = self._run_command("cat /proc/loadavg")
        if output and not output.startswith("Error"):
            parts = output.split()
            if len(parts) >= 4:
                load_info["load_1min"] = float(parts[0])
                load_info["load_5min"] = float(parts[1])
                load_info["load_15min"] = float(parts[2])
                proc_parts = parts[3].split("/")
                if len(proc_parts) == 2:
                    load_info["running_processes"] = int(proc_parts[0])
                    load_info["total_processes"] = int(proc_parts[1])

        return load_info

    def get_installed_packages(self, limit: int = 50) -> List[str]:
        """获取已安装的软件包列表"""
        output = self._run_command(f"pacman -Q | head -{limit}")
        if output and not output.startswith("Error"):
            return output.split("\n")
        return []

    def search_packages(self, keyword: str) -> List[str]:
        """搜索软件包"""
        output = self._run_command(f"pacman -Ss {keyword} | head -20")
        if output and not output.startswith("Error"):
            return output.split("\n")
        return []
