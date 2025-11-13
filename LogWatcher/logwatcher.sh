#!/bin/bash
# ===========================================================
#  LogWatcher v4 - Enterprise Edition
#  Real-Time UFW Intrusion Detector, Auto-Ban & JSON Logging
#  Author: Roy
# ===========================================================

# ---------- [1] BASE DIRECTORIES ----------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Folder where this script lives
LOG_DIR="$BASE_DIR/logs"                                  # For our own logs
CONFIG_DIR="$BASE_DIR/config"                             # For config/whitelist
BANNED_DIR="$BASE_DIR/banned"                             # For banned IP history

# UFW logs on your system are in kern.log (we checked already)
WATCH_FILE="/var/log/kern.log"
REPORT_FILE="$LOG_DIR/logwatcher.log"                     # Human-readable log
JSON_LOG="$LOG_DIR/logwatcher.jsonl"                      # JSON lines log
BANNED_LIST="$BANNED_DIR/banned_ips.txt"                  # History of bans
CONFIG_FILE="$CONFIG_DIR/logwatcher.conf"                 # Optional config
WHITELIST_FILE="$CONFIG_DIR/whitelist_ips.conf"           # Optional whitelist

# ---------- [2] DEFAULT THRESHOLDS & FLAGS ----------
MAX_BLOCKS=5           # Ban if IP has >= 5 blocked events (any port)
MAX_SSH_BLOCKS=3       # Faster reaction if it's SSH (port 22)
ENABLE_JSON=1          # 1 = write JSON log, 0 = disable
DRY_RUN=0              # 1 = do NOT call ufw, only log what WOULD happen

# ---------- [3] COLORS ----------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# ---------- [4] HELPER: TIMESTAMP ----------
timestamp() {
  # Return date like: 2025-11-13 21:23:45
  date '+%Y-%m-%d %H:%M:%S'
}

# ---------- [5] HUMAN-READABLE LOG WRAPPER ----------
log_msg() {
  # $1 = text (with possible colors)
  local msg="[$(timestamp)] $1"
  echo -e "$msg" | tee -a "$REPORT_FILE"
}

# ---------- [6] JSON LOG HELPERS ----------
log_json() {
  # $1 = event type (e.g. "ban", "ssh_alert", "info")
  # $2 = IP
  # $3 = block_count
  # $4 = is_ssh (0/1)
  local event="$1"
  local ip="$2"
  local count="$3"
  local is_ssh="$4"

  [[ "$ENABLE_JSON" -ne 1 ]] && return 0

  # Simple JSON line (no original log line to avoid escaping hell)
  printf '{"ts":"%s","event":"%s","ip":"%s","count":%s,"ssh":%s}\n' \
    "$(timestamp)" "$event" "$ip" "$count" "$is_ssh" >> "$JSON_LOG"
}

# ---------- [7] LOAD CONFIG (IF EXISTS) ----------
load_config() {
  # If user created config/logwatcher.conf, source it.
  # Safe enough for your own machine.
  if [[ -f "$CONFIG_FILE" ]]; then
    # The config can override: MAX_BLOCKS, MAX_SSH_BLOCKS, ENABLE_JSON, DRY_RUN, WATCH_FILE, etc.
    # Example file:
    #   MAX_BLOCKS=7
    #   MAX_SSH_BLOCKS=4
    #   ENABLE_JSON=1
    #   DRY_RUN=0
    source "$CONFIG_FILE"
    log_msg "${GREEN}⚙️  Loaded config from $CONFIG_FILE${RESET}"
  fi
}

# ---------- [8] ENSURE DIRECTORIES & FILES ----------
init_dirs() {
  mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BANNED_DIR"
  touch "$BANNED_LIST" "$JSON_LOG"

  # Create whitelist file if it doesn't exist (user can edit later)
  if [[ ! -f "$WHITELIST_FILE" ]]; then
    echo "# Add one IP per line to whitelist" > "$WHITELIST_FILE"
  fi
}

# ---------- [9] ROOT CHECK ----------
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run as root (sudo ./logwatcher.sh ...)"
    exit 1
  fi
}

# ---------- [10] WHITELIST CHECK ----------
is_whitelisted() {
  local ip="$1"
  # Ignore comments and empty lines, match exact IP
  grep -E "^[[:space:]]*${ip}[[:space:]]*$" "$WHITELIST_FILE" >/dev/null 2>&1
}

# ---------- [11] BAN FUNCTION ----------
ban_ip() {
  local ip="$1"
  local count="$2"

  # Don't touch whitelisted IPs
  if is_whitelisted "$ip"; then
    log_msg "${YELLOW}🛡️  $ip is whitelisted. Skipping ban.${RESET}"
    log_json "whitelisted_skip" "$ip" "$count" 0
    return 0
  fi

  # Already banned?
  if grep -q "$ip" "$BANNED_LIST"; then
    log_msg "${YELLOW}↩️  IP already banned: $ip${RESET}"
    log_json "already_banned" "$ip" "$count" 0
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_msg "${YELLOW}🧪 [DRY-RUN] Would ban IP: $ip ($count blocks)${RESET}"
    log_json "dry_run_ban" "$ip" "$count" 0
  else
    ufw deny from "$ip" >/dev/null 2>&1
    echo "$(timestamp) $ip ($count blocks)" >> "$BANNED_LIST"
    log_msg "${RED}⛔ BANNED IP: $ip  (total $count blocks)${RESET}"
    log_json "ban" "$ip" "$count" 0
  fi
}

# ---------- [12] PROCESS SINGLE LOG LINE ----------
process_line() {
  local line="$1"

  # Only care about UFW BLOCK lines
  [[ "$line" != *"UFW BLOCK"* ]] && return 0

  # Extract IPv4 from SRC=
  local ip
  ip=$(echo "$line" | grep -oP 'SRC=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

  # If no IPv4 (maybe IPv6), skip
  [[ -z "$ip" ]] && return 0

  # Skip whitelisted before even counting
  if is_whitelisted "$ip"; then
    log_msg "${YELLOW}🛡️  Ignoring whitelisted IP in logs: $ip${RESET}"
    log_json "whitelisted_seen" "$ip" 0 0
    return 0
  fi

  # Count how many times this IP appeared in the log file
  local block_count
  block_count=$(grep -F "SRC=$ip" "$WATCH_FILE" | wc -l)

  # SSH detection (port 22)
  local ssh_attack=0
  [[ "$line" == *"DPT=22"* ]] && ssh_attack=1

  if [[ $ssh_attack -eq 1 && $block_count -ge $MAX_SSH_BLOCKS ]]; then
    log_msg "${YELLOW}⚠️ SSH Attack detected from $ip ($block_count attempts)${RESET}"
    log_json "ssh_alert" "$ip" "$block_count" 1
  fi

  # General auto-ban rule
  if [[ $block_count -ge $MAX_BLOCKS ]]; then
    ban_ip "$ip" "$block_count"
  fi
}

# ---------- [13] ONE-TIME SCAN MODE ----------
run_once() {
  log_msg "${BLUE}🧾 Running one-time scan on: $WATCH_FILE${RESET}"

  local bad_ips
  bad_ips=$(grep "UFW BLOCK" "$WATCH_FILE" \
    | grep -oP 'SRC=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort \
    | uniq -c \
    | sort -nr)

  [[ -z "$bad_ips" ]] && {
    log_msg "No suspicious IPs found in log."
    return 0
  }

  echo "$bad_ips" | while read -r count ip; do
    [[ -z "$ip" ]] && continue

    # Skip whitelist here as well
    if is_whitelisted "$ip"; then
      log_msg "${YELLOW}🛡️  Skipping whitelisted IP in scan: $ip${RESET}"
      log_json "whitelisted_scan_skip" "$ip" "$count" 0
      continue
    fi

    # SSH attempts count (history)
    local ssh_count
    ssh_count=$(grep "UFW BLOCK" "$WATCH_FILE" | grep "SRC=$ip" | grep -c "DPT=22")

    if [[ $ssh_count -ge $MAX_SSH_BLOCKS ]]; then
      log_msg "${YELLOW}⚠️ SSH brute-force pattern: $ip ($ssh_count SSH attempts)${RESET}"
      log_json "ssh_bruteforce" "$ip" "$ssh_count" 1
    fi

    if [[ $count -ge $MAX_BLOCKS ]]; then
      ban_ip "$ip" "$count"
    else
      log_msg "ℹ️ IP $ip has $count blocks (below threshold)."
      log_json "below_threshold" "$ip" "$count" 0
    fi
  done

  log_msg "${GREEN}✅ One-time scan completed.${RESET}"
}

# ---------- [14] REPORT MODE ----------
show_report() {
  log_msg "${BLUE}📊 Banned IPs report:${RESET}"

  if [[ ! -s "$BANNED_LIST" ]]; then
    echo "No IPs banned yet."
    return 0
  fi

  cat "$BANNED_LIST"
}

# ---------- [15] REAL-TIME WATCH MODE ----------
watch_realtime() {
  log_msg "${BLUE}🔍 Starting LogWatcher v4 — Real-Time Mode...${RESET}"
  log_msg "Monitoring: $WATCH_FILE"
  log_msg "Thresholds: MAX_BLOCKS=$MAX_BLOCKS, MAX_SSH_BLOCKS=$MAX_SSH_BLOCKS, DRY_RUN=$DRY_RUN"

  # -F = follow file even if it rotates
  # -n0 = start from end (only new lines)
  tail -Fn0 "$WATCH_FILE" | while read -r line; do
    process_line "$line"
  done
}

# ---------- [16] INITIALIZATION ----------
init_dirs
require_root
load_config

# ---------- [17] ARGUMENT PARSING ----------
case "${1:-}" in
  --once)
    run_once
    ;;
  --report)
    show_report
    ;;
  --dry-run)
    DRY_RUN=1
    watch_realtime
    ;;
  --help|-h)
    echo "Usage: sudo ./logwatcher.sh [--once | --report | --dry-run]"
    echo "  (no args)  Real-time watch mode (auto-ban enabled)"
    echo "  --once     One-time scan and auto-ban"
    echo "  --report   Show banned IP history"
    echo "  --dry-run  Real-time mode WITHOUT changing UFW (no real bans)"
    ;;
  "" )
    watch_realtime
    ;;
  *)
    echo "Unknown option: $1"
    echo "Try: sudo ./logwatcher.sh --help"
    exit 1
    ;;
esac
