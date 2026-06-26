#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║        SSH Management Panel - نصب خودکار                                              ║"
echo "║              برای Ubuntu 22 LTS و بالاتر                                               ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════════╝"
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
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📝 لطفاً اطلاعات مورد نیاز را وارد کنید:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

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

# درخواست استفاده از دومین DuoProxy
echo ""
echo -e "${YELLOW}🌐 آیا می‌خواهید از دومین DuoProxy استفاده کنید؟${NC}"
read -p "آیا دومین DuoProxy دارید؟ (y/n) [پیش‌فرض: n]: " USE_DUOPROXY
USE_DUOPROXY=${USE_DUOPROXY:-n}

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo -e "${YELLOW}💡 مثال: panel.yourdomain.com یا ssh-panel.yourdomain.com${NC}"
    read -p "🔗 دومین/ساب‌دومین DuoProxy را وارد کنید: " DUOPROXY_DOMAIN
    
    if [ -z "$DUOPROXY_DOMAIN" ]; then
        echo -e "${RED}❌ دومین نمی‌تواند خالی باشد${NC}"
        DUOPROXY_DOMAIN=""
        USE_DUOPROXY="n"
    else
        ACCESS_URL="https://$DUOPROXY_DOMAIN"
        PANEL_HOST="127.0.0.1"
    fi
else
    # درخواست آدرس IP/Hostname
    echo ""
    echo -e "${YELLOW}ℹ️ برای دسترسی از تمام رابط‌ها (0.0.0.0) یا فقط localhost انتخاب کنید${NC}"
    read -p "🌐 آدرس IP/Hostname [پیش‌فرض: 0.0.0.0]: " PANEL_HOST
    PANEL_HOST=${PANEL_HOST:-0.0.0.0}

    # دریافت آدرس IP واقعی
    REAL_IP=$(hostname -I | awk '{print $1}')
    if [ "$PANEL_HOST" = "0.0.0.0" ]; then
        ACCESS_URL="http://$REAL_IP:$PANEL_PORT"
    else
        ACCESS_URL="http://$PANEL_HOST:$PANEL_PORT"
    fi
fi

echo ""
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
PANEL_PORT=$PANEL_PORT
FLASK_HOST=$PANEL_HOST
EOF

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo "DUOPROXY_DOMAIN=$DUOPROXY_DOMAIN" >> "$INSTALL_PATH/.env"
fi

# ایجاد اسکریپت راه‌اندازی
cat > "$INSTALL_PATH/run.sh" << 'RUNSCRIPT'
#!/bin/bash
source $(dirname "$0")/venv/bin/activate
cd $(dirname "$0")
python3 app.py
RUNSCRIPT
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
echo "╔════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║              ✅ نصب با موفقیت انجام شد!                                                ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}📋 اطلاعات دسترسی:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 آدرس پنل:${NC}        $ACCESS_URL"
echo -e "${GREEN}👤 نام کاربری:${NC}      $ADMIN_USER"
echo -e "${GREEN}🔐 رمز عبور:${NC}       $ADMIN_PASS"
echo -e "${GREEN}🔌 پورت:${NC}           $PANEL_PORT"
echo -e "${GREEN}📁 مسیر نصب:${NC}       $INSTALL_PATH"

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo -e "${GREEN}🔗 دومین DuoProxy:${NC}   $DUOPROXY_DOMAIN"
    echo -e "${YELLOW}💡 نکته: پنل فقط روی localhost در حال اجرا است. از DuoProxy برای دسترسی استفاده کنید.${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

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
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🚀 دستورات مفید:${NC}"
echo ""
echo "📋 دستورات سرویس:"
echo -e "   ${BLUE}• مشاهده لاگ:${NC}              sudo journalctl -u ssh-panel -f"
echo -e "   ${BLUE}• شروع مجدد:${NC}              sudo systemctl restart ssh-panel"
echo -e "   ${BLUE}• توقف سرویس:${NC}             sudo systemctl stop ssh-panel"
echo -e "   ${BLUE}• وضعیت سرویس:${NC}            sudo systemctl status ssh-panel"
echo ""
echo "📂 فایل‌های اصلی:"
echo -e "   ${BLUE}• مسیر نصب:${NC}               $INSTALL_PATH"
echo -e "   ${BLUE}• فایل .env:${NC}              $INSTALL_PATH/.env"
echo -e "   ${BLUE}• دیتابیس:${NC}                $INSTALL_PATH/ssh_panel.db"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
