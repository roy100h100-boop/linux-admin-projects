#!/bin/bash
# ===========================================================
#  UFW Guardian v4 - Backup Edition (Final Boss)
#  Author: Roy
#  Purpose: Fully automated, self-healing UFW firewall manager
# ===========================================================

# ----------[1] BASE DIRECTORY SETUP ----------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$BASE_DIR/config/ufw_allowed_ports.conf"
LOG_DIR="$BASE_DIR/logs"
BACKUP_DIR="$BASE_DIR/backups"
LOG_FILE="$LOG_DIR/ufw_guardian.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ----------[2] AUTO-CREATE REQUIRED FOLDERS ----------
mkdir -p "$LOG_DIR" "$BASE_DIR/config" "$BACKUP_DIR"

# ----------[3] ROOT PERMISSION CHECK ----------
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

# ----------[4] COLOR VARIABLES ----------
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
BLUE=$(tput setaf 6)
RESET=$(tput sgr0)

# ----------[5] LOG FUNCTION ----------
log() {
  echo -e "[$DATE] $1" | tee -a "$LOG_FILE"
}

# ----------[6] STARTUP MESSAGE ----------
log "${BLUE}🔒 Starting UFW Guardian v4...${RESET}"

# ----------[7] ENSURE SYSTEMD MANAGES UFW ----------
if systemctl list-unit-files | grep -q "ufw.service"; then
  systemctl unmask ufw >/dev/null 2>&1
  systemctl enable ufw >/dev/null 2>&1
  systemctl start ufw >/dev/null 2>&1
else
  log "${YELLOW}⚠️  systemd not managing UFW on this system.${RESET}"
fi

# ----------[8] ENSURE /etc/ufw/ufw.conf ENABLED ----------
if grep -q "ENABLED=no" /etc/ufw/ufw.conf 2>/dev/null; then
  sed -i 's/ENABLED=no/ENABLED=yes/' /etc/ufw/ufw.conf
  log "${YELLOW}⚙️  Updated /etc/ufw/ufw.conf to ENABLED=yes${RESET}"
fi

# ----------[9] ENABLE UFW IF INACTIVE ----------
if ! ufw status | grep -q "active"; then
  log "${YELLOW}⚙️  UFW inactive — enabling now...${RESET}"
  /usr/sbin/ufw --force enable >/dev/null 2>&1
  sleep 2
  if ufw status | grep -q "active"; then
    log "${GREEN}✅ UFW successfully enabled and active.${RESET}"
  else
    log "${RED}❌ UFW failed to enable. Check systemctl and /etc/ufw/ufw.conf.${RESET}"
    exit 1
  fi
else
  log "${GREEN}✅ UFW already active.${RESET}"
fi

# ----------[10] DEFAULT POLICIES ----------
ufw default deny incoming
ufw default allow outgoing
log "${BLUE}🔧 Default policy: deny incoming, allow outgoing.${RESET}"

# ----------[11] LOAD ALLOWED PORTS ----------
log "${BLUE}📜 Loading allowed ports from config...${RESET}"

# If no config file, create a default one
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "22\n80\n443" > "$CONFIG_FILE"
  log "${YELLOW}Created default config with ports 22, 80, 443${RESET}"
fi

while read -r port; do
  [[ -z "$port" || "$port" =~ ^# ]] && continue
  ufw allow "$port" >/dev/null 2>&1
  log "${GREEN}✅ Allowed port: $port${RESET}"
done < "$CONFIG_FILE"

# ----------[12] ENABLE LOGGING + RELOAD ----------
ufw logging on
ufw reload
log "${GREEN}🔁 Firewall reloaded and logging enabled.${RESET}"

# ----------[13] SHOW FINAL STATUS ----------
log "${BLUE}🧱 Firewall setup complete.${RESET}"
echo "----------------------------------------" | tee -a "$LOG_FILE"
ufw status verbose | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# ===========================================================
#                      RESET MODE (V4)
# ===========================================================
if [[ $1 == "--reset" ]]; then
  read -p "⚠️  Are you sure you want to reset UFW? (y/n): " confirm
  if [[ $confirm == "y" ]]; then

    # ---------- BACKUP SYSTEM ----------
    timestamp=$(date +%Y%m%d_%H%M%S)
    RULE_FILES=("user.rules" "before.rules" "after.rules" "user6.rules" "before6.rules" "after6.rules")

    echo "🔐 Creating UFW backups..."
    for file in "${RULE_FILES[@]}"; do
      SRC="/etc/ufw/$file"
      SYSTEM_DEST="/etc/ufw/${file}.${timestamp}"
      PROJECT_DEST="$BACKUP_DIR/${file}.${timestamp}"

      if [[ -f "$SRC" ]]; then
        echo "📦 Backing up $file → $SYSTEM_DEST"
        cp "$SRC" "$SYSTEM_DEST"

        echo "📁 Saving project copy → $PROJECT_DEST"
        cp "$SRC" "$PROJECT_DEST"
      else
        echo "⚠️ File not found: $file (skipped)"
      fi
    done

    # ---------- RESET FIREWALL ----------
    ufw --force reset
    log "${RED}⚠️  Firewall rules reset to default.${RESET}"

    exit 0
  else
    echo "❎ Cancelled."
    exit 0
  fi
fi

# ===========================================================
#                        ADD MODE
# ===========================================================
if [[ $1 == "--add" ]]; then
  read -p "Enter port number to allow: " newport
  ufw allow "$newport"
  echo "$newport" >> "$CONFIG_FILE"
  log "${GREEN}✅ Added and allowed port: $newport${RESET}"
  exit 0
fi

# ===========================================================
#                       STATUS MODE
# ===========================================================
if [[ $1 == "--status" ]]; then
  ufw status verbose
  exit 0
fi
