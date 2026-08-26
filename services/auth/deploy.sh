#!/bin/bash
set -e

# ============================================================
# CNomarchy 认证后端一键部署脚本
# 适用于 Ubuntu 22.04 / 24.04 / Debian 12
# 使用方式: sudo bash deploy.sh
# ============================================================

echo "=========================================="
echo "  CNomarchy 认证后端部署脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 变量
APP_DIR="/opt/cnomarchy/auth"
SERVICE_NAME="cnomarchy-auth"
DOMAIN=${1:-"api.cnomarchy.local"}

echo "📦 安装系统依赖..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv nginx git curl

echo "📂 创建应用目录..."
mkdir -p $APP_DIR
cd $APP_DIR

echo "🐍 创建 Python 虚拟环境..."
python3 -m venv venv
source venv/bin/activate

echo "📥 安装 Python 依赖..."
pip install --upgrade pip -q
pip install -r requirements.txt -q

echo "⚙️  配置环境变量..."
if [ ! -f .env ]; then
    cp .env.example .env
    # 生成随机密钥
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/your-secret-key-here/$SECRET_KEY/" .env
    echo "  已生成随机 SECRET_KEY"
    echo "  ⚠️  请编辑 .env 文件，配置短信服务商信息"
fi

echo "🔧 配置 systemd 服务..."
cp deploy/cnomarchy-auth.service /etc/systemd/system/
sed -i "s|/opt/cnomarchy/auth|$APP_DIR|g" /etc/systemd/system/$SERVICE_NAME.service
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo "🌐 配置 Nginx..."
cp deploy/nginx.conf /etc/nginx/sites-available/$SERVICE_NAME
sed -i "s/api.cnomarchy.local/$DOMAIN/g" /etc/nginx/sites-available/$SERVICE_NAME
ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "✅ 配置防火墙..."
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 下一步操作："
echo "  1. 编辑配置文件: nano $APP_DIR/.env"
echo "     - 配置短信服务商（阿里云/腾讯云）的 API Key"
echo "     - 修改 SECRET_KEY（已自动生成）"
echo "  2. 重启服务: systemctl restart $SERVICE_NAME"
echo "  3. 检查状态: systemctl status $SERVICE_NAME"
echo "  4. 查看日志: journalctl -u $SERVICE_NAME -f"
echo ""
echo "🌐 API 地址: http://$DOMAIN"
echo "📖 API 文档: http://$DOMAIN/docs"
echo ""
echo "🔐 如需 HTTPS，可使用 certbot:"
echo "  apt install certbot python3-certbot-nginx"
echo "  certbot --nginx -d $DOMAIN"
echo ""
