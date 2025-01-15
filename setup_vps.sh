#!/usr/bin/env bash
###############################################################################
# VPS Setup and Security Script (Debian/Ubuntu)
# 1. Create an admin user + SSH keys
# 2. SSH hardening (port, root login denial, public key only)
# 3. System updates & basic installations
# 4. UFW firewall configuration
# 5. Fail2Ban installation & configuration
# 6. Timezone configuration & disable unnecessary services
# 7. Docker installation
# 8. SSH test
# 9. Install Zsh, Oh My Zsh & powerlevel10k
# 10.  Cleanup
#
# At the end: an OK/X summary for each section
###############################################################################

# -------------------------------------------------------------------------
#                        SECTION STATUS MANAGEMENT
# -------------------------------------------------------------------------
section1_status="N/A"
section2_status="N/A"
section3_status="N/A"
section4_status="N/A"
section5_status="N/A"
section6_status="N/A"
section7_status="N/A"
section8_status="N/A"
section9_status="N/A" 

# -------------------------------------------------------------------------
#                       LOGIC & CHECK FUNCTIONS
# -------------------------------------------------------------------------

check_command() {
  if [ $? -ne 0 ]; then
    echo -e "\e[31m[ERROR] The last command failed.\e[0m"
    return 1
  else
    echo -e "\e[32m[OK] Command executed successfully.\e[0m"
    return 0
  fi
}

finalize_section() {
  local section_var_name="$1"
  local return_code="$2"
  if [ "$return_code" -ne 0 ]; then
    eval "$section_var_name=\"X\""
  else
    eval "$section_var_name=\"OK\""
  fi
}

disable_service() {
  local service_name=$1
  if systemctl list-unit-files | grep -q "^${service_name}.service"; then
    echo "-> Disabling service: $service_name"
    systemctl stop "$service_name"
    check_command
    systemctl disable "$service_name"
    check_command
  fi
}

# -------------------------------------------------------------------------
#                               PREREQUISITES
# -------------------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root (or via sudo)."
  exit 1
fi

DEFAULT_USER=$(logname) 
ADMIN_USER="admin" # Specify the admin username
SSH_PORT="2109" # Specify the desired SSH port
PUB_KEY_PATH="/home/$DEFAULT_USER/.ssh/VPS-Mlucas.pub" # Path to your public SSH key
ADMIN_AUTHORIZED_KEYS="/home/$ADMIN_USER/.ssh/authorized_keys" # Admin user's authorized_keys file

# -------------------------------------------------------------------------
#                     1. CREATE ADMIN USER + CONFIGURE SSH
# -------------------------------------------------------------------------

echo "========================================================================"
echo "1. CREATE ADMIN USER + CONFIGURE SSH"
echo "========================================================================"

(
  # Check if the user already exists
  id "$ADMIN_USER" &>/dev/null
  if [ $? -ne 0 ]; then
    echo "-> Creating user: $ADMIN_USER"
    adduser --gecos "" --disabled-password "$ADMIN_USER"
    echo "$ADMIN_USER:adminpassword" | chpasswd
    check_command || exit 1

    echo "-> Adding $ADMIN_USER to the sudo group"
    usermod -aG sudo "$ADMIN_USER"
    check_command || exit 1
  else
    echo "-> User $ADMIN_USER already exists, skipping."
  fi

  # Check if the public key exists
  if [ -f "$PUB_KEY_PATH" ]; then
    echo "-> Copying public SSH key for user $ADMIN_USER"
    mkdir -p /home/"$ADMIN_USER"/.ssh
    cat "$PUB_KEY_PATH" >> "$ADMIN_AUTHORIZED_KEYS"
    chmod 700 /home/"$ADMIN_USER"/.ssh
    chmod 600 "$ADMIN_AUTHORIZED_KEYS"
    chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh
    check_command || exit 1

    # Clean up the temporary public key
    rm -f "$PUB_KEY_PATH"
  else
    echo -e "\e[31m[ERROR] Public key not found at $PUB_KEY_PATH.\e[0m"
    echo "Please copy the public key using the following command before running this script:"
    echo "scp VPS-Mlucas.pub $DEFAULT_USER@<IP>:~/.ssh/VPS-Mlucas.pub"
    exit 1
  fi
)
section1_code=$?
finalize_section "section1_status" "$section1_code"

# -------------------------------------------------------------------------
#                           2. SSH HARDENING
# -------------------------------------------------------------------------

echo "========================================================================"
echo "2. SSH HARDENING"
echo "========================================================================"

(
  SSHD_CONFIG="/etc/ssh/sshd_config"
  if [ ! -f "${SSHD_CONFIG}.bak" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
  fi

  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/g' "$SSHD_CONFIG"
  check_command || exit 1

  sed -i "s/^#\?Port .*/Port $SSH_PORT/g" "$SSHD_CONFIG"
  check_command || exit 1

  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/g' "$SSHD_CONFIG"
  check_command || exit 1

  sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/g' "$SSHD_CONFIG"
  check_command || exit 1

  echo "-> Restarting the SSH service"
  systemctl restart ssh
  check_command || exit 1
)
section2_code=$?
finalize_section "section2_status" "$section2_code"

# -------------------------------------------------------------------------
#                3. SYSTEM UPDATES & BASIC TOOLS INSTALLATION
# -------------------------------------------------------------------------

echo "========================================================================"
echo "3. SYSTEM UPDATES & BASIC TOOLS INSTALLATION"
echo "========================================================================"

(
  # Disable interaction during installation
  export DEBIAN_FRONTEND=noninteractive

  # Update the package list
  apt-get update -y
  check_command || exit 1

  # Upgrade installed packages (preserving modified config files)
  apt-get -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      upgrade
  check_command || exit 1

  # Install basic utilities
  apt-get install -y curl wget vim git htop
  check_command || exit 1

  # Install unattended-upgrades (without interaction)
  apt-get install -y unattended-upgrades
  check_command || exit 1

  # Automatically configure unattended-upgrades (skip the dialog screen)
  dpkg-reconfigure -f noninteractive -plow unattended-upgrades
  check_command || exit 1
)
section3_code=$?
finalize_section "section3_status" "$section3_code"

# -------------------------------------------------------------------------
#                          4. FIREWALL CONFIGURATION (UFW)
# -------------------------------------------------------------------------

echo "========================================================================"
echo "4. FIREWALL CONFIGURATION (UFW)"
echo "========================================================================"

(
  apt-get install -y ufw
  check_command || exit 1

  ufw --force reset
  check_command || exit 1

  ufw default deny incoming
  check_command || exit 1
  ufw default allow outgoing
  check_command || exit 1

  ufw allow "$SSH_PORT"/tcp
  check_command || exit 1

  ufw allow 80/tcp
  ufw allow 443/tcp

  ufw --force enable
  check_command || exit 1

  ufw status verbose
)
section4_code=$?
finalize_section "section4_status" "$section4_code"

# -------------------------------------------------------------------------
#                        5. INSTALLATION OF FAIL2BAN
# -------------------------------------------------------------------------

echo "========================================================================"
echo "5. INSTALLATION & CONFIGURATION OF FAIL2BAN"
echo "========================================================================"

(
  # 1) Install fail2ban + rsyslog to ensure /var/log/auth.log exists
  apt-get install -y fail2ban rsyslog
  check_command || exit 1
  
  # Ensure rsyslog is running
  systemctl enable rsyslog
  check_command || exit 1
  systemctl start rsyslog
  check_command || exit 1
  
  FAIL2BAN_JAIL="/etc/fail2ban/jail.local"
  
  # 2) Create jail.local from jail.conf if it doesn't exist
  if [ ! -f "$FAIL2BAN_JAIL" ]; then
    echo "-> Creating $FAIL2BAN_JAIL from jail.conf"
    cp /etc/fail2ban/jail.conf "$FAIL2BAN_JAIL"
    check_command || exit 1
  fi
  
  # 3) Enable the [sshd] jail and configure port and logpath in jail.local
  sed -i '/^\[sshd\]/,/^$/ { 
      s/^enabled\s*=.*/enabled = true/g
      s/^port\s*=.*/port = '"$SSH_PORT"'/g
      s|^logpath\s*=.*|logpath = /var/log/auth.log|g
    }' "$FAIL2BAN_JAIL"
  check_command || exit 1
  
  # 4) Enable and restart Fail2Ban
  systemctl enable fail2ban
  check_command || exit 1
  
  systemctl restart fail2ban
  check_command || exit 1
)
section5_code=$?
finalize_section "section5_status" "$section5_code"

# -------------------------------------------------------------------------
#              6. TIMEZONE CONFIGURATION & DISABLE SERVICES
# -------------------------------------------------------------------------

echo "========================================================================"
echo "6. TIMEZONE CONFIGURATION & DISABLE SERVICES"
echo "========================================================================"

(
  TIMEZONE="Europe/Paris"
  timedatectl set-timezone "$TIMEZONE"
  check_command || exit 1

  apt-get install -y chrony
  check_command || exit 1
  systemctl enable chrony
  check_command || exit 1
  systemctl start chrony
  check_command || exit 1

  disable_service "apache2"
  disable_service "postfix"
)
section6_code=$?
finalize_section "section6_status" "$section6_code"

# -------------------------------------------------------------------------
#                     7. DOCKER INSTALLATION
# -------------------------------------------------------------------------

echo "========================================================================"
echo "7. DOCKER INSTALLATION"
echo "========================================================================"

(
  apt-get install -y ca-certificates curl gnupg
  check_command || exit 1

  install -m 0755 -d /etc/apt/keyrings
  check_command || exit 1

  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  check_command || exit 1

  chmod a+r /etc/apt/keyrings/docker.gpg
  check_command || exit 1

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  check_command || exit 1

  apt-get update -y
  check_command || exit 1

  # Install Docker
  apt-get install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
  check_command || exit 1

  usermod -aG docker "$ADMIN_USER"
  check_command || exit 1
  systemctl enable docker
  check_command || exit 1
  systemctl start docker
  check_command || exit 1
)
section7_code=$?
finalize_section "section7_status" "$section7_code"

# -------------------------------------------------------------------------
#              8. SSH TEST (optional if private key is available)
# -------------------------------------------------------------------------

echo "========================================================================"
echo "8. SSH TEST"
echo "========================================================================"

(
  if [ -f "$ROOT_PRIVATE_KEY" ]; then
    echo "-> Testing SSH connection to localhost:$SSH_PORT as $ADMIN_USER"
    ssh -i "$ROOT_PRIVATE_KEY" \
        -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=no \
        "$ADMIN_USER@localhost" \
        "echo 'SSH success!'" 2>/dev/null
    check_command || exit 1
  else
    echo -e "\e[33m[WARNING] Root private key not found ($ROOT_PRIVATE_KEY), skipping SSH test.\e[0m"
  fi
)
section8_code=$?
finalize_section "section8_status" "$section8_code"

# -------------------------------------------------------------------------
#       9. INSTALLATION OF ZSH, OH MY ZSH & POWERLEVEL10K FOR $ADMIN_USER
# -------------------------------------------------------------------------

echo "========================================================================"
echo "9. INSTALLATION OF ZSH + OH MY ZSH + POWERLEVEL10K"
echo "========================================================================"

(
  # 9A. Install Zsh & dependencies for Powerline (if needed)
  apt-get install -y zsh fonts-powerline
  check_command || exit 1

  # 9B. Set Zsh as the default shell for the admin user
  chsh -s "$(which zsh)" "$ADMIN_USER"
  check_command || exit 1

  # 9C. Install Oh My Zsh for $ADMIN_USER
  su -c "
    export RUNZSH=no
    sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" 
  " -s /bin/bash "$ADMIN_USER"
  check_command || exit 1

  # 9D. Install Powerlevel10k
  su -c "
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-/home/$ADMIN_USER/.oh-my-zsh/custom}/themes/powerlevel10k
  " -s /bin/bash "$ADMIN_USER"
  check_command || exit 1

  # 9E. Update .zshrc to use Powerlevel10k
  ZSHRC="/home/$ADMIN_USER/.zshrc"
  su -c "
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME=\"powerlevel10k\\/powerlevel10k\"/' $ZSHRC
  " -s /bin/bash "$ADMIN_USER"
  check_command || exit 1

  # 9F. Adjust permissions if needed
  chown "$ADMIN_USER":"$ADMIN_USER" -R "/home/$ADMIN_USER/"
)
section9_code=$?
finalize_section "section9_status" "$section9_code"

# -------------------------------------------------------------------------
#              10. CLEANUP & REMOVAL OF DEFAULT USER
# -------------------------------------------------------------------------

echo "========================================================================"
echo "10. CLEANUP & REMOVAL OF DEFAULT USER"
echo "========================================================================"

(
  # If the default user is 'debian', remove it.
  # Ensure we do not accidentally delete 'root'!
  if [ "$DEFAULT_USER" != "root" ] && [ "$DEFAULT_USER" != "$ADMIN_USER" ]; then
    echo "-> Removing default user '$DEFAULT_USER'"
    userdel -r "$DEFAULT_USER"
    check_command || exit 1
  else
    echo "-> Skipping removal: the default user is '$DEFAULT_USER', which is either root or already admin."
  fi

  # (Optional) Remove the script itself
  echo "-> Deleting the current script: $0"
  rm -- "$0"
)
section10_code=$?
finalize_section "section10_status" "$section10_code"

# -------------------------------------------------------------------------
#                         FINAL SUMMARY
# -------------------------------------------------------------------------

echo "========================================================================"
echo "                       FINAL SUMMARY OF SECTIONS"
echo "========================================================================"

echo "1. ADMIN USER + SSH CONFIG        : $section1_status"
echo "2. SSH HARDENING                  : $section2_status"
echo "3. SYSTEM UPDATES & TOOLS         : $section3_status"
echo "4. UFW FIREWALL                   : $section4_status"
echo "5. FAIL2BAN                       : $section5_status"
echo "6. TIMEZONE & SERVICES            : $section6_status"
echo "7. DOCKER                         : $section7_status"
echo "8. SSH TEST                       : $section8_status"
echo "9. ZSH + OH MY ZSH + P10K         : $section9_status"
echo "10. CLEANUP                       : $section10_status"

echo "========================================================================"
echo "Script completed!"
echo "========================================================================"
echo "You can now try connecting as '$ADMIN_USER' on port '$SSH_PORT'."
echo "Example: ssh -p $SSH_PORT $ADMIN_USER@<server-IP>"
echo
echo "Next time you log in as $ADMIN_USER,"
echo "you'll be greeted by Zsh with Oh My Zsh + powerlevel10k!"
