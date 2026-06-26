#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        SSH Management Panel - نصاب خودکار              ║"
echo "║              برای Ubuntu 22 LTS و بالاتر                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# بررسی دسترسی root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ این اسکریپت باید با دسترسی root اجرا شود${NC}"
    echo "دستور صحیح: sudo bash install.sh"
    exit 1
fi

echo -e "${YELLOW}⏳ بررسی و نصب پکیج‌های مورد نیاز...${NC}\n"
apt update -qq > /dev/null 2>&1
apt install -y -qq python3-pip python3-venv git curl wget > /dev/null 2>&1

echo -e "${GREEN}✅ پکیج‌ها نصب شدند${NC}\n"

# درخواست اطلاعات از کاربر
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📝 لطفاً اطلاعات مورد نیاز را وارد کنید:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# درخواست نام کاربری
while true; do
    read -p "👤 نام کاربری مدیر (Admin Username): " ADMIN_USER
    if [ -z "$ADMIN_USER" ]; then
        echo -e "${RED}❌ نام کاربری نمی‌تواند خالی باشد${NC}"
        continue
    fi
    break
done

# درخواست رمز عبور
while true; do
    read -sp "🔐 رمز عبور مدیر (Admin Password): " ADMIN_PASS
    echo ""
    if [ -z "$ADMIN_PASS" ]; then
        echo -e "${RED}❌ رمز عبور نمی‌تواند خالی باشد${NC}"
        continue
    fi
    break
done

# درخواست پورت
while true; do
    read -p "🔌 پورت پنل (Port) [پیش‌فرض: 5000]: " PANEL_PORT
    PANEL_PORT=${PANEL_PORT:-5000}
    if ! [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$PANEL_PORT" -lt 1 ] || [ "$PANEL_PORT" -gt 65535 ]; then
        echo -e "${RED}❌ پورت باید عدد بین 1 تا 65535 باشد${NC}"
        continue
    fi
    break
done

# درخواست آدرس
echo ""
echo -e "${YELLOW}ℹ️ برای دسترسی از تمام رابط‌ها (0.0.0.0) یا فقط localhost انتخاب کنید${NC}"
read -p "🌐 آدرس IP/Hostname [پیش‌فرض: 0.0.0.0]: " PANEL_HOST
PANEL_HOST=${PANEL_HOST:-0.0.0.0}

echo ""

# دریافت آدرس IP واقعی
REAL_IP=$(hostname -I | awk '{print $1}')
if [ "$PANEL_HOST" = "0.0.0.0" ]; then
    ACCESS_URL="http://$REAL_IP:$PANEL_PORT"
else
    ACCESS_URL="http://$PANEL_HOST:$PANEL_PORT"
fi

echo -e "${YELLOW}📁 انتخاب مسیر نصب:${NC}"
echo "  1) /opt/ssh-panel (پیش‌فرض - توصیه شده)"
echo "  2) /home/ssh-panel"
echo "  3) مسیر سفارشی"
read -p "انتخاب کنید (1-3) [پیش‌فرض: 1]: " INSTALL_CHOICE
INSTALL_CHOICE=${INSTALL_CHOICE:-1}

case $INSTALL_CHOICE in
    1)
        INSTALL_PATH="/opt/ssh-panel"
        ;;
    2)
        INSTALL_PATH="/home/ssh-panel"
        ;;
    3)
        read -p "مسیر سفارشی را وارد کنید: " INSTALL_PATH
        ;;
    *)
        INSTALL_PATH="/opt/ssh-panel"
        ;;
esac

echo ""
echo -e "${YELLOW}⏳ نصب پنل در $INSTALL_PATH...${NC}\n"

# ایجاد دایرکتوری
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# دانلود فایل‌ها
echo -e "${YELLOW}📥 دانلود فایل‌های پروژه...${NC}"
git clone https://github.com/alireza11598203/alireza11598203.git . 2>/dev/null || git pull origin main > /dev/null 2>&1

# ایجاد virtual environment
echo -e "${YELLOW}🐍 ایجاد Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# نصب dependencies
echo -e "${YELLOW}📦 نصب Python packages...${NC}"
pip install -q --upgrade pip setuptools wheel > /dev/null 2>&1
pip install -q -r requirements.txt > /dev/null 2>&1

# ایجاد فایل کنفیگ
echo -e "${YELLOW}⚙️ ایجاد فایل تنظیمات...${NC}"

cat > "$INSTALL_PATH/.env" << EOF
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
DATABASE_URL=sqlite:///ssh_panel.db
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
EOF

# ایجاد اسکریپت راه‌انداز
cat > "$INSTALL_PATH/run.sh" << 'EOF'
#!/bin/bash
source $(dirname "$0")/venv/bin/activate
cd $(dirname "$0")
python3 app.py
EOF
chmod +x "$INSTALL_PATH/run.sh"

# ایجاد سرویس systemd
echo -e "${YELLOW}🔧 ایجاد سرویس systemd...${NC}"

cat > /etc/systemd/system/ssh-panel.service << EOF
[Unit]
Description=SSH Management Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/venv/bin/python3 $INSTALL_PATH/app.py
Environment="FLASK_ENV=production"
Environment="FLASK_HOST=$PANEL_HOST"
Environment="FLASK_PORT=$PANEL_PORT"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# تغییر مالکیت
chown -R root:root "$INSTALL_PATH"
chmod 750 "$INSTALL_PATH"

# فعال‌سازی سرویس
systemctl daemon-reload
systemctl enable ssh-panel > /dev/null 2>&1
systemctl restart ssh-panel

echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✅ نصب با موفقیت انجام شد!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}📋 اطلاعات دسترسی:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 آدرس پنل:${NC}        $ACCESS_URL"
echo -e "${GREEN}👤 نام کاربری:${NC}      $ADMIN_USER"
echo -e "${GREEN}🔐 رمز عبور:${NC}       $ADMIN_PASS"
echo -e "${GREEN}🔌 پورت:${NC}           $PANEL_PORT"
echo -e "${GREEN}📁 مسیر نصب:${NC}       $INSTALL_PATH"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}🚀 راهنمای سریع:${NC}"
echo ""
echo "📌 دستورات مفید:"
echo -e "   ${BLUE}• مشاهده لاگ:${NC}              sudo journalctl -u ssh-panel -f"
echo -e "   ${BLUE}• شروع مجدد:${NC}              sudo systemctl restart ssh-panel"
echo -e "   ${BLUE}• توقف سرویس:${NC}             sudo systemctl stop ssh-panel"
echo -e "   ${BLUE}• وضعیت سرویس:${NC}            sudo systemctl status ssh-panel"
echo ""
echo -e "${YELLOW}⏳ در حال بارگذاری... (چند لحظه منتظر بمانید)${NC}"
sleep 3

# بررسی وضعیت سرویس
if systemctl is-active --quiet ssh-panel; then
    echo -e "${GREEN}✅ سرویس با موفقیت راه‌اندازی شد!${NC}"
    echo ""
    echo -e "${GREEN}🎉 نصب کامل شد!${NC}"
    echo -e "${YELLOW}حالا می‌توانید به پنل وارد شوید:${NC}"
    echo ""
    echo -e "${BLUE}➜  $ACCESS_URL${NC}"
    echo ""
else
    echo -e "${RED}⚠️ مشکلی در راه‌اندازی سرویس وجود دارد${NC}"
    echo "برای دیدن لاگ‌ها دستور زیر را اجرا کنید:"
    echo "sudo journalctl -u ssh-panel -n 50"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
