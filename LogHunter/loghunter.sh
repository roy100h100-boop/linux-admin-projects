#!/bin/bash
#============================================================
# LogHunter : Simple SSH Attack Detector by Roy
#============================================================

LOGFILE="/var/log/loghunter.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=============================" >> "$LOGFILE"
echo "LogHunter Report - $DATE" >> "$LOGFILE"
echo "=============================" >> "$LOGFILE"

# 1. Show total number of failed SSH login attempts
echo "[Total Failed SSH Logins]" >> "$LOGFILE"
grep --text -E "Failed password|Invalid user|authentication failure" /var/log/auth.log | wc -l >> "$LOGFILE"
echo "" >> "$LOGFILE"

# 2. Show top 5 offending IP addresses
echo "[Top 5 Source IPs]" >> "$LOGFILE"
grep --text -E "Failed password|Invalid user|authentication failure" /var/log/auth.log \
  | awk '{for(i=1;i<=NF;i++){if($i=="from"){print $(i+1)}}}' \
  | sort | uniq -c | sort -nr | head -n 5 >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "Report complete ✅" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# ==============================
# Safe Auto-Blocker (Mission 2B)
# ==============================

# Use a home location so we avoid permission/locking issues
BLOCKFILE="/home/roy/block_suggestions.txt"
DATE2=$(date '+%Y-%m-%d %H:%M:%S')

echo "# Suggested firewall blocks (generated $DATE2)" > "$BLOCKFILE"

# build suggestions (does NOT apply them)
grep --text -E "Failed password|Invalid user|authentication failure" /var/log/auth.log \
  | awk '{for(i=1;i<=NF;i++){if($i=="from"){print $(i+1)}}}' \
  | sort | uniq -c | sort -nr | head -n 10 \
  | awk '{print "ufw deny from "$2}' >> "$BLOCKFILE"

# Log where suggestions are saved
echo "Block suggestions saved to $BLOCKFILE" >> "$LOGFILE"
echo "" >> "$LOGFILE"
