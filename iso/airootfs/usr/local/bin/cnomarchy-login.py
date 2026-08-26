#!/usr/bin/env python3
"""
CNomarchy 手机号登录界面
系统启动时显示，用户通过手机号 + 短信验证码登录
"""

import tkinter as tk
from tkinter import ttk, messagebox
import json
import os
import sys
import re
import time
import threading
import urllib.request
import urllib.error
import ssl

# ============================================================
# 配置
# ============================================================
CONFIG_DIR = os.path.expanduser("~/.cnomarchy")
CONFIG_FILE = os.path.join(CONFIG_DIR, "auth.json")
TOKEN_FILE = os.path.join(CONFIG_DIR, "token")
DEVICE_FILE = os.path.join(CONFIG_DIR, "device")

# 后端 API 地址（部署后修改为实际地址）
# 默认使用本地回环，部署时通过环境变量或配置文件修改
API_BASE = os.environ.get("CNOMARCHY_API", "https://api.cnomarchy.local/v1")

# SSL 上下文（自签名证书时禁用验证）
ctx = ssl.create_default_context()
if os.environ.get("CNOMARCHY_SSL_INSECURE"):
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE


class LoginApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CNomarchy 登录")
        self.root.geometry("420x520")
        self.root.resizable(False, False)
        self.root.configure(bg="#1a1a2e")

        # 居中显示
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() - 420) // 2
        y = (self.root.winfo_screenheight() - 520) // 2
        self.root.geometry(f"420x520+{x}+{y}")

        self.countdown = 0
        self.countdown_running = False

        self._build_ui()
        self._check_auto_login()

    def _build_ui(self):
        """构建界面"""
        # 主容器
        main = tk.Frame(self.root, bg="#1a1a2e")
        main.pack(fill="both", expand=True, padx=40, pady=30)

        # Logo / 标题
        title_frame = tk.Frame(main, bg="#1a1a2e")
        title_frame.pack(pady=(10, 30))

        tk.Label(
            title_frame,
            text="CNomarchy",
            font=("Segoe UI", 28, "bold"),
            fg="#e94560",
            bg="#1a1a2e"
        ).pack()

        tk.Label(
            title_frame,
            text="AI 原生操作系统",
            font=("Segoe UI", 11),
            fg="#888888",
            bg="#1a1a2e"
        ).pack(pady=(5, 0))

        # 手机号输入
        phone_frame = tk.Frame(main, bg="#1a1a2e")
        phone_frame.pack(fill="x", pady=(0, 15))

        tk.Label(
            phone_frame,
            text="手机号",
            font=("Segoe UI", 10),
            fg="#aaaaaa",
            bg="#1a1a2e"
        ).pack(anchor="w")

        self.phone_var = tk.StringVar()
        phone_entry = tk.Entry(
            phone_frame,
            textvariable=self.phone_var,
            font=("Segoe UI", 14),
            bg="#16213e",
            fg="#ffffff",
            insertbackground="#e94560",
            relief="flat",
            bd=0
        )
        phone_entry.pack(fill="x", ipady=10, pady=(5, 0))
        phone_entry.bind("<KeyRelease>", self._on_phone_key)

        # 分割线
        tk.Frame(phone_frame, height=1, bg="#0f3460").pack(fill="x")

        # 验证码输入 + 获取按钮
        code_frame = tk.Frame(main, bg="#1a1a2e")
        code_frame.pack(fill="x", pady=(0, 15))

        tk.Label(
            code_frame,
            text="验证码",
            font=("Segoe UI", 10),
            fg="#aaaaaa",
            bg="#1a1a2e"
        ).pack(anchor="w")

        code_input_frame = tk.Frame(code_frame, bg="#1a1a2e")
        code_input_frame.pack(fill="x", pady=(5, 0))

        self.code_var = tk.StringVar()
        code_entry = tk.Entry(
            code_input_frame,
            textvariable=self.code_var,
            font=("Segoe UI", 14),
            bg="#16213e",
            fg="#ffffff",
            insertbackground="#e94560",
            relief="flat",
            bd=0,
            width=20
        )
        code_entry.pack(side="left", fill="x", expand=True, ipady=10)

        self.send_code_btn = tk.Button(
            code_input_frame,
            text="获取验证码",
            font=("Segoe UI", 10),
            fg="#ffffff",
            bg="#0f3460",
            activebackground="#16213e",
            activeforeground="#e94560",
            relief="flat",
            bd=0,
            cursor="hand2",
            command=self._send_code
        )
        self.send_code_btn.pack(side="right", padx=(10, 0), ipady=8, ipadx=10)

        # 分割线
        tk.Frame(code_frame, height=1, bg="#0f3460").pack(fill="x")

        # 记住设备
        self.remember_var = tk.BooleanVar(value=True)
        remember_check = tk.Checkbutton(
            main,
            text="记住此设备，下次自动登录",
            variable=self.remember_var,
            font=("Segoe UI", 10),
            fg="#aaaaaa",
            bg="#1a1a2e",
            activebackground="#1a1a2e",
            activeforeground="#ffffff",
            selectcolor="#16213e",
            relief="flat",
            bd=0
        )
        remember_check.pack(anchor="w", pady=(5, 20))

        # 登录按钮
        self.login_btn = tk.Button(
            main,
            text="登 录",
            font=("Segoe UI", 14, "bold"),
            fg="#ffffff",
            bg="#e94560",
            activebackground="#c73e54",
            activeforeground="#ffffff",
            relief="flat",
            bd=0,
            cursor="hand2",
            command=self._login
        )
        self.login_btn.pack(fill="x", ipady=12)

        # 状态提示
        self.status_label = tk.Label(
            main,
            text="",
            font=("Segoe UI", 9),
            fg="#888888",
            bg="#1a1a2e",
            wraplength=340
        )
        self.status_label.pack(pady=(15, 0))

        # 底部信息
        bottom_frame = tk.Frame(main, bg="#1a1a2e")
        bottom_frame.pack(side="bottom", pady=(10, 0))

        tk.Label(
            bottom_frame,
            text="登录即表示同意《用户协议》和《隐私政策》",
            font=("Segoe UI", 8),
            fg="#555555",
            bg="#1a1a2e"
        ).pack()

    def _on_phone_key(self, event):
        """手机号输入时只允许数字"""
        value = self.phone_var.get()
        cleaned = re.sub(r'\D', '', value)[:11]
        if cleaned != value:
            self.phone_var.set(cleaned)

    def _set_status(self, text, color="#888888"):
        """设置状态提示"""
        self.status_label.config(text=text, fg=color)

    def _api_call(self, endpoint, method="GET", data=None):
        """调用后端 API"""
        url = f"{API_BASE}{endpoint}"
        headers = {"Content-Type": "application/json"}

        # 如果有 token，添加到 header
        token = self._load_token()
        if token:
            headers["Authorization"] = f"Bearer {token}"

        body = json.dumps(data).encode("utf-8") if data else None

        req = urllib.request.Request(url, data=body, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            try:
                error_data = json.loads(e.read().decode("utf-8"))
                return {"error": error_data.get("detail", str(e))}
            except:
                return {"error": str(e)}
        except Exception as e:
            return {"error": f"网络连接失败: {str(e)}"}

    def _send_code(self):
        """发送验证码"""
        phone = self.phone_var.get().strip()

        if not phone:
            self._set_status("请输入手机号", "#e94560")
            return
        if not re.match(r'^1[3-9]\d{9}$', phone):
            self._set_status("手机号格式不正确", "#e94560")
            return

        self.send_code_btn.config(state="disabled")
        self._set_status("正在发送验证码...")

        def do_send():
            result = self._api_call("/auth/send-code", method="POST", data={"phone": phone})
            self.root.after(0, lambda: self._on_code_sent(result))

        threading.Thread(target=do_send, daemon=True).start()

    def _on_code_sent(self, result):
        """验证码发送结果"""
        if "error" in result:
            self._set_status(f"发送失败: {result['error']}", "#e94560")
            self.send_code_btn.config(state="normal")
            return

        self._set_status("验证码已发送，请注意查收短信", "#4ecca3")
        self._start_countdown(60)

    def _start_countdown(self, seconds):
        """开始倒计时"""
        self.countdown = seconds
        self.countdown_running = True

        def tick():
            if self.countdown > 0:
                self.send_code_btn.config(text=f"{self.countdown}秒后重发", state="disabled")
                self.countdown -= 1
                self.root.after(1000, tick)
            else:
                self.send_code_btn.config(text="获取验证码", state="normal")
                self.countdown_running = False

        tick()

    def _login(self):
        """登录"""
        phone = self.phone_var.get().strip()
        code = self.code_var.get().strip()

        if not phone:
            self._set_status("请输入手机号", "#e94560")
            return
        if not code:
            self._set_status("请输入验证码", "#e94560")
            return

        self.login_btn.config(state="disabled", text="登录中...")
        self._set_status("正在验证...")

        def do_login():
            result = self._api_call(
                "/auth/verify-code",
                method="POST",
                data={"phone": phone, "code": code, "remember": self.remember_var.get()}
            )
            self.root.after(0, lambda: self._on_login_result(result, phone))

        threading.Thread(target=do_login, daemon=True).start()

    def _on_login_result(self, result, phone):
        """登录结果"""
        if "error" in result:
            self._set_status(f"登录失败: {result['error']}", "#e94560")
            self.login_btn.config(state="normal", text="登 录")
            return

        # 保存 token
        token = result.get("token", "")
        if token:
            self._save_token(token)

        # 保存设备信息
        if self.remember_var.get():
            self._save_device(phone, result.get("device_id", ""))

        self._set_status("登录成功，正在进入系统...", "#4ecca3")

        # 延迟1秒后启动桌面
        self.root.after(1000, self._start_desktop)

    def _start_desktop(self):
        """启动桌面环境"""
        self.root.destroy()
        # 启动 Hyprland（通过 systemd 或 startx）
        os.system("Hyprland &")
        sys.exit(0)

    def _check_auto_login(self):
        """检查是否可以自动登录"""
        device = self._load_device()
        token = self._load_token()

        if device and token:
            self._set_status("检测到已登录设备，正在自动登录...", "#4ecca3")
            self.phone_var.set(device.get("phone", ""))

            def do_auto_login():
                result = self._api_call("/auth/refresh", method="POST")
                self.root.after(0, lambda: self._on_auto_login_result(result))

            threading.Thread(target=do_auto_login, daemon=True).start()

    def _on_auto_login_result(self, result):
        """自动登录结果"""
        if "error" not in result and result.get("token"):
            self._save_token(result["token"])
            self._set_status("自动登录成功，正在进入系统...", "#4ecca3")
            self.root.after(1000, self._start_desktop)
        else:
            self._set_status("自动登录失败，请手动登录", "#e94560")

    def _load_token(self):
        """加载 token"""
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, "r") as f:
                    return f.read().strip()
        except:
            pass
        return ""

    def _save_token(self, token):
        """保存 token"""
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(TOKEN_FILE, "w") as f:
                f.write(token)
            os.chmod(TOKEN_FILE, 0o600)
        except:
            pass

    def _load_device(self):
        """加载设备信息"""
        try:
            if os.path.exists(DEVICE_FILE):
                with open(DEVICE_FILE, "r") as f:
                    return json.load(f)
        except:
            pass
        return None

    def _save_device(self, phone, device_id):
        """保存设备信息"""
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(DEVICE_FILE, "w") as f:
                json.dump({"phone": phone, "device_id": device_id}, f)
            os.chmod(DEVICE_FILE, 0o600)
        except:
            pass


def main():
    root = tk.Tk()
    app = LoginApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
