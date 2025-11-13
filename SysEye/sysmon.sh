#!/bin/bash
# =====================================================
# SysEye: Simple System Monitor by Roy
# =====================================================

# Set safe PATH for cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LOGFILE="/var/log/sysmon.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "============================" >> "$LOGFILE"
echo "SysEye Report - $DATE" >> "$LOGFILE"
echo "============================" >> "$LOGFILE"

echo "[Uptime]" >> "$LOGFILE"
uptime >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "[Memory Usage]" >> "$LOGFILE"
free -h >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "[Disk Usage]" >> "$LOGFILE"
df -h --total | grep total >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "[Top 5 CPU Processes]" >> "$LOGFILE"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "[Per-Core CPU Usage]" >> "$LOGFILE"
# -P ALL = show all cores
# 1 1 = sample for 1 second, once
mpstat -P ALL 1 1 >> "$LOGFILE"
echo "" >> "$LOGFILE"

echo "Report complete ✅" >> "$LOGFILE"
echo "" >> "$LOGFILE"
