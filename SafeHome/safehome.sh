#!/bin/bash
# ===============================
# SafeHome – Daily Backup Script
# Author: Roy
# ===============================

# 1️⃣ Set variables
SOURCE_DIR="/home/roy"
BACKUP_DIR="/backups"
LOG_FILE="/var/log/safehome.log"
T7_PATH="/media/roy/T7 Shield"  # ✅ Real directory path

# Load private configuration file (contains ALERT_EMAIL)
source /etc/safehome.conf

# 2️⃣ Create backup directory if it doesn’t exist
mkdir -p "$BACKUP_DIR"

# 3️⃣ Generate timestamp and backup name
DATE=$(date +'%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/roy_backup_$DATE.tar.gz"

# 4️⃣ Start backup process
echo "[$(date)] Starting backup..." | tee -a "$LOG_FILE"

# Exclude volatile folders and capture exit code
tar --exclude="$HOME/.cache/google-chrome" \
    --exclude="$HOME/.config/google-chrome/Default" \
    --exclude="$HOME/.cache/ibus" \
    -czf "$BACKUP_FILE" "$SOURCE_DIR" 2>>"$LOG_FILE"

tar_exit=$?
if [ $tar_exit -eq 0 ] || [ $tar_exit -eq 1 ]; then
    # 0 = perfect, 1 = warnings only (still valid backup)
    echo "[$(date)] Backup completed successfully (code $tar_exit): $BACKUP_FILE" | tee -a "$LOG_FILE"
else
    echo "[$(date)] ❌ Backup failed (tar exit code $tar_exit)!" | tee -a "$LOG_FILE"
    exit 1
fi

# 🔐 Encrypt the backup file with GPG
ENCRYPTED_FILE="${BACKUP_FILE}.gpg"

# Encrypt using the public key (non-interactive)
gpg --batch --yes --output "$ENCRYPTED_FILE" \
    --encrypt --recipient BB83C48C7A3CA97D89D1C30F9DE8DD6D4BAB8748 \
    "$BACKUP_FILE" 2>>"$LOG_FILE"

gpg_exit=$?
if [ $gpg_exit -eq 0 ]; then
    echo "[$(date)] Encrypted backup created: $ENCRYPTED_FILE" | tee -a "$LOG_FILE"
    rm -f "$BACKUP_FILE"   # remove plaintext only after successful encryption
else
    echo "[$(date)] ❌ Encryption failed (gpg exit $gpg_exit)!" | tee -a "$LOG_FILE"
    exit 1
fi

# 6️⃣ Check if T7 drive is connected and copy the file

if [ -d "$T7_PATH" ]; then
    cp "$ENCRYPTED_FILE" "$T7_PATH"/
    echo "[$(date)] Copied ENCRYPTED backup to T7 drive." | tee -a "$LOG_FILE"
else
    echo "[$(date)] T7 drive not found, skipping copy." | tee -a "$LOG_FILE"
fi

# 7️⃣ Cleanup old backups (older than 7 days)
find "$BACKUP_DIR" -type f -mtime +7 -name "*.tar.gz" -delete
echo "[$(date)] Old backups cleaned." | tee -a "$LOG_FILE"

# 8️⃣ Email and Desktop Notifications
# read only the last 30 lines of the log for this run
if tail -n 30 "$LOG_FILE" | grep -q "❌ Backup failed"; then
    echo "SafeHome backup FAILED at $(date)" \
        | mail -s "❌ SafeHome Backup Failed" "$ALERT_EMAIL"

    if command -v notify-send >/dev/null 2>&1 && \
       pgrep -x "notification-daemon" >/dev/null 2>&1; then
        notify-send "SafeHome Backup" "❌ Backup failed! Check $LOG_FILE for details."
    fi
else
    echo "SafeHome backup completed successfully at $(date)" \
        | mail -s "✅ SafeHome Backup Success" "$ALERT_EMAIL"

    if command -v notify-send >/dev/null 2>&1 && \
       pgrep -x "notification-daemon" >/dev/null 2>&1; then
        notify-send "SafeHome Backup" "✅ Backup completed successfully!"
    fi
fi


# ✅ Done
echo "[$(date)] Backup completed successfully!" | tee -a "$LOG_FILE"
exit 0
