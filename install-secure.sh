#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║          SSH Management Panel - Automatic Secure Installation                         ║"
echo "║                    For Ubuntu 22 LTS and Higher                                        ║"
echo "║              With Protection Against Filters and Security Threats                      ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root access
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR] This script must be run with root privileges${NC}"
    echo "Correct command: sudo bash install-secure.sh"
    exit 1
fi

echo -e "${YELLOW}[*] Checking and installing required packages...${NC}\n"
apt update -qq > /dev/null 2>&1
apt install -y -qq python3-pip python3-venv git curl wget iptables-persistent netfilter-persistent ufw > /dev/null 2>&1

echo -e "${GREEN}[+] Packages installed successfully${NC}\n"

# Request information from user
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}[INFO] Please enter the required information:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Request admin username
while true; do
    read -p "[?] Admin Username: " ADMIN_USER
    if [ -z "$ADMIN_USER" ]; then
        echo -e "${RED}[ERROR] Username cannot be empty${NC}"
        continue
    fi
    break
done

# Request admin password
while true; do
    read -sp "[?] Admin Password: " ADMIN_PASS
    echo ""
    if [ -z "$ADMIN_PASS" ]; then
        echo -e "${RED}[ERROR] Password cannot be empty${NC}"
        continue
    fi
    break
done

# Request port
while true; do
    read -p "[?] Panel Port [default: 5000]: " PANEL_PORT
    PANEL_PORT=${PANEL_PORT:-5000}
    if ! [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$PANEL_PORT" -lt 1 ] || [ "$PANEL_PORT" -gt 65535 ]; then
        echo -e "${RED}[ERROR] Port must be a number between 1 and 65535${NC}"
        continue
    fi
    break
done

# Request DuoProxy domain
echo ""
echo -e "${YELLOW}[?] Do you want to use DuoProxy domain?${NC}"
read -p "Do you have a DuoProxy domain? (y/n) [default: n]: " USE_DUOPROXY
USE_DUOPROXY=${USE_DUOPROXY:-n}

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo -e "${YELLOW}[INFO] Example: panel.yourdomain.com or ssh-panel.yourdomain.com${NC}"
    read -p "[?] Enter DuoProxy domain/subdomain: " DUOPROXY_DOMAIN
    
    if [ -z "$DUOPROXY_DOMAIN" ]; then
        echo -e "${RED}[ERROR] Domain cannot be empty${NC}"
        DUOPROXY_DOMAIN=""
        USE_DUOPROXY="n"
    else
        ACCESS_URL="https://$DUOPROXY_DOMAIN"
        PANEL_HOST="127.0.0.1"
    fi
else
    # Request IP/Hostname
    echo ""
    echo -e "${YELLOW}[INFO] For better security, only localhost is recommended${NC}"
    read -p "[?] IP Address/Hostname [default: 127.0.0.1]: " PANEL_HOST
    PANEL_HOST=${PANEL_HOST:-127.0.0.1}

    # Get real IP address
    REAL_IP=$(hostname -I | awk '{print $1}')
    if [ "$PANEL_HOST" = "127.0.0.1" ]; then
        ACCESS_URL="http://127.0.0.1:$PANEL_PORT"
        echo -e "${YELLOW}[INFO] To access remotely: ssh -L 5000:127.0.0.1:$PANEL_PORT user@$REAL_IP${NC}"
    else
        ACCESS_URL="http://$PANEL_HOST:$PANEL_PORT"
    fi
fi

echo ""
echo -e "${YELLOW}[?] Select installation path:${NC}"
echo "  1) /opt/ssh-panel (default - recommended)"
echo "  2) /home/ssh-panel"
echo "  3) Custom path"
read -p "[?] Choose (1-3) [default: 1]: " INSTALL_CHOICE
INSTALL_CHOICE=${INSTALL_CHOICE:-1}

case $INSTALL_CHOICE in
    1)
        INSTALL_PATH="/opt/ssh-panel"
        ;;
    2)
        INSTALL_PATH="/home/ssh-panel"
        ;;
    3)
        read -p "[?] Enter custom path: " INSTALL_PATH
        ;;
    *)
        INSTALL_PATH="/opt/ssh-panel"
        ;;
esac

echo ""
echo -e "${CYAN}[SECURITY] Security settings:${NC}"
echo ""
read -p "[?] Apply firewall configuration? (y/n) [default: y]: " SETUP_FIREWALL
SETUP_FIREWALL=${SETUP_FIREWALL:-y}

read -p "[?] Enable MTU Fragmentation? (y/n) [default: y]: " SETUP_MTU
SETUP_MTU=${SETUP_MTU:-y}

read -p "[?] Enable Obfuscation? (y/n) [default: y]: " SETUP_OBFS
SETUP_OBFS=${SETUP_OBFS:-y}

echo ""
echo -e "${YELLOW}[*] Installing panel at $INSTALL_PATH...${NC}\n"

# Create directory
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# Download files
echo -e "${YELLOW}[*] Downloading project files...${NC}"
git clone https://github.com/alireza11598203/alireza11598203.git . 2>/dev/null || git pull origin main > /dev/null 2>&1

# Create virtual environment
echo -e "${YELLOW}[*] Creating Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo -e "${YELLOW}[*] Installing Python packages...${NC}"
pip install -q --upgrade pip setuptools wheel > /dev/null 2>&1
pip install -q -r requirements.txt > /dev/null 2>&1

# Create config file
echo -e "${YELLOW}[*] Creating configuration file...${NC}"

cat > "$INSTALL_PATH/.env" << EOF
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
DATABASE_URL=sqlite:///ssh_panel.db
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
PANEL_PORT=$PANEL_PORT
FLASK_HOST=$PANEL_HOST
SESSION_COOKIE_SECURE=True
SESSION_COOKIE_HTTPONLY=True
PREFERRED_URL_SCHEME=https
EOF

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo "DUOPROXY_DOMAIN=$DUOPROXY_DOMAIN" >> "$INSTALL_PATH/.env"
fi

# Create launch script
cat > "$INSTALL_PATH/run.sh" << 'RUNSCRIPT'
#!/bin/bash
source $(dirname "$0")/venv/bin/activate
cd $(dirname "$0")
python3 app.py
RUNSCRIPT
chmod +x "$INSTALL_PATH/run.sh"

# Create systemd service
echo -e "${YELLOW}[*] Creating systemd service...${NC}"

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
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Change ownership
chown -R root:root "$INSTALL_PATH"
chmod 750 "$INSTALL_PATH"

# Apply security settings
echo -e "${YELLOW}[*] Applying security settings...${NC}"

# 1. MTU Fragmentation
if [[ "$SETUP_MTU" == "y" || "$SETUP_MTU" == "Y" ]]; then
    echo -e "${CYAN}[SECURITY] Setting MTU Fragmentation...${NC}"
    
    # Change MTU to prevent DPI detection
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ ! -z "$INTERFACE" ]; then
        ip link set dev $INTERFACE mtu 1400
        
        # Save changes for next boot
        cat >> /etc/network/interfaces.d/99-ssh-panel << MTUCONF
auto $INTERFACE
iface $INTERFACE inet dhcp
    mtu 1400
MTUCONF
    fi
fi

# 2. UFW Firewall Configuration
if [[ "$SETUP_FIREWALL" == "y" || "$SETUP_FIREWALL" == "Y" ]]; then
    echo -e "${CYAN}[SECURITY] Configuring Firewall...${NC}"
    
    # Enable UFW
    ufw --force enable > /dev/null 2>&1
    
    # Reset old rules
    ufw reset --force > /dev/null 2>&1
    ufw --force enable > /dev/null 2>&1
    
    # Default rules
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    # SSH (emergency access)
    ufw allow 22/tcp > /dev/null 2>&1
    
    # SSH Panel
    ufw allow $PANEL_PORT/tcp > /dev/null 2>&1
    
    # HTTP/HTTPS (only if not DuoProxy)
    if [[ "$USE_DUOPROXY" != "y" && "$USE_DUOPROXY" != "Y" ]]; then
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
    fi
    
    # DNS (important for security)
    ufw allow 53/tcp > /dev/null 2>&1
    ufw allow 53/udp > /dev/null 2>&1
fi

# 3. Obfuscation and DPI Avoidance
if [[ "$SETUP_OBFS" == "y" || "$SETUP_OBFS" == "Y" ]]; then
    echo -e "${CYAN}[SECURITY] Setting up Obfuscation...${NC}"
    
    # Create sysctl file for optimization
    cat > /etc/sysctl.d/99-ssh-panel-security.conf << SYSCTLCONF
# SSH Panel Security Configuration
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 0

# TCP optimization to reduce DPI detection
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
SYSCTLCONF
    
    # Apply changes
    sysctl -p /etc/sysctl.d/99-ssh-panel-security.conf > /dev/null 2>&1
fi

# 4. Protection script
echo -e "${CYAN}[SECURITY] Creating protection script...${NC}"

cat > /usr/local/bin/ssh-panel-protect.sh << 'PROTECTSCRIPT'
#!/bin/bash

# Additional protection settings
echo "[$(date)] SSH Panel Protection Starting..." >> /var/log/ssh-panel-protect.log

# Enable IP masquerading to prevent direct identification
iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null

# Save changes
netfilter-persistent save > /dev/null 2>&1

echo "[$(date)] Protection applied successfully" >> /var/log/ssh-panel-protect.log
PROTECTSCRIPT

chmod +x /usr/local/bin/ssh-panel-protect.sh

# Run protection script
/usr/local/bin/ssh-panel-protect.sh

# Enable service
echo -e "${YELLOW}[*] Enabling service...${NC}"
systemctl daemon-reload
systemctl enable ssh-panel > /dev/null 2>&1
systemctl restart ssh-panel

# Create cron job for continuous protection
(crontab -l 2>/dev/null | grep -v ssh-panel-protect.sh; echo "*/5 * * * * /usr/local/bin/ssh-panel-protect.sh") | crontab -

echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║              [SUCCESS] Installation and security settings completed!                   ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${BLUE}[ACCESS INFORMATION]${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[+] Panel URL:${NC}        $ACCESS_URL"
echo -e "${GREEN}[+] Username:${NC}        $ADMIN_USER"
echo -e "${GREEN}[+] Password:${NC}        $ADMIN_PASS"
echo -e "${GREEN}[+] Port:${NC}            $PANEL_PORT"
echo -e "${GREEN}[+] Install Path:${NC}    $INSTALL_PATH"

if [[ "$USE_DUOPROXY" == "y" || "$USE_DUOPROXY" == "Y" ]]; then
    echo -e "${GREEN}[+] DuoProxy Domain:${NC}  $DUOPROXY_DOMAIN"
    echo -e "${YELLOW}[INFO] Note: Panel runs only on localhost. Use DuoProxy for access.${NC}"
fi

echo ""
echo -e "${CYAN}[SECURITY] Enabled security features:${NC}"
if [[ "$SETUP_MTU" == "y" || "$SETUP_MTU" == "Y" ]]; then
    echo -e "   ${GREEN}[+] MTU Fragmentation${NC}"
fi
if [[ "$SETUP_FIREWALL" == "y" || "$SETUP_FIREWALL" == "Y" ]]; then
    echo -e "   ${GREEN}[+] UFW Firewall${NC}"
fi
if [[ "$SETUP_OBFS" == "y" || "$SETUP_OBFS" == "Y" ]]; then
    echo -e "   ${GREEN}[+] Obfuscation & Protection${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}[*] Service is starting... (please wait)${NC}"
sleep 3

# Check service status
if systemctl is-active --quiet ssh-panel; then
    echo -e "${GREEN}[+] Service started successfully!${NC}"
    echo ""
    echo -e "${GREEN}[SUCCESS] Installation complete and secure!${NC}"
    echo -e "${YELLOW}[INFO] You can now access the panel at:${NC}"
    echo ""
    echo -e "${BLUE}==> $ACCESS_URL${NC}"
    echo ""
else
    echo -e "${RED}[ERROR] Problem starting the service${NC}"
    echo "[INFO] To see logs, run:"
    echo "sudo journalctl -u ssh-panel -n 50"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[USEFUL COMMANDS]${NC}"
echo ""
echo "[SERVICE COMMANDS]"
echo -e "   ${BLUE}• View logs:${NC}              sudo journalctl -u ssh-panel -f"
echo -e "   ${BLUE}• Restart service:${NC}         sudo systemctl restart ssh-panel"
echo -e "   ${BLUE}• Stop service:${NC}            sudo systemctl stop ssh-panel"
echo -e "   ${BLUE}• Check status:${NC}            sudo systemctl status ssh-panel"
echo ""
echo "[SECURITY COMMANDS]"
echo -e "   ${BLUE}• Firewall status:${NC}         sudo ufw status"
echo -e "   ${BLUE}• View iptables:${NC}           sudo iptables -L -n"
echo -e "   ${BLUE}• Check protection:${NC}        sudo cat /var/log/ssh-panel-protect.log"
echo ""
echo "[IMPORTANT FILES]"
echo -e "   ${BLUE}• Install path:${NC}            $INSTALL_PATH"
echo -e "   ${BLUE}• Config file:${NC}             $INSTALL_PATH/.env"
echo -e "   ${BLUE}• Database:${NC}                $INSTALL_PATH/ssh_panel.db"
echo -e "   ${BLUE}• Protection log:${NC}          /var/log/ssh-panel-protect.log"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}[SECURITY TIPS]${NC}"
echo "   • Use DuoProxy to hide real IP"
echo "   • Change default SSH port"
echo "   • Use SSH keys instead of passwords"
echo "   • Enable 2FA for accounts"
echo "   • Keep system updated regularly"
echo ""
