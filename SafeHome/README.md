# 🏠 SafeHome – Encrypted Automated Backup System by Roy

## 📄 Overview
**SafeHome** is a secure and fully automated Linux backup system designed to protect important data with **GPG encryption**, **external drive synchronization**, and **email notifications**.  
It performs scheduled daily backups via `cron`, encrypts them with your GPG public key, and stores both local and external copies for redundancy.  

---

## ⚙️ Features
- 🔐 **GPG encryption** (asymmetric public/private key system)
- 💾 **Automated daily backups** via cron
- 🧩 **Smart folder exclusions** (Chrome cache, temporary files)
- 📤 **Automatic copy to external T7 SSD drive**
- 📧 **Email & desktop notifications** for success/failure
- 🧹 **Automatic cleanup** of backups older than 7 days
- 🪶 Lightweight Bash implementation — no heavy dependencies

---

## 🧱 Directory Structure


/home/roy/Projects/linux-admin-projects/SafeHome/
├── safehome.sh → main backup script
├── /etc/safehome.conf → private config file (contains ALERT_EMAIL)
└── README.md → documentation file


---

## 🔐 Encryption Setup (GPG)
1️⃣ **Generate your GPG key pair:**
```bash
sudo gpg --full-generate-key


Choose:

Type: RSA and RSA (default)

Size: 4096 bits

Expiration: 0 (never expires)

Name/Email: use your real info

Comment: SafeHome Backup Encryption

2️⃣ List and export your public key:

gpg --list-keys
gpg --armor --export "roy100h100@gmail.com" > /etc/safehome_public.asc


3️⃣ Store private key safely offline.
Only the public key is used by the backup system for encryption, so cron jobs can run without prompting for passwords.

🧰 Configuration

Create a small config file to store your email:

sudo nano /etc/safehome.conf


Inside it, add:

ALERT_EMAIL="your_email@gmail.com"

🧠 How It Works

Compresses your home directory /home/roy into a .tar.gz file.

Encrypts it with your GPG public key.

Saves it to /backups.

Copies the encrypted file to your external T7 SSD (/media/roy/T7 Shield).

Deletes backups older than 7 days.

Sends an email notification through msmtp (Gmail relay).

🕐 Cron Automation

To schedule SafeHome to run every night at 2:00 AM:

sudo crontab -e


Add this line:

0 2 * * * /home/roy/Projects/linux-admin-projects/SafeHome/safehome.sh >> /var/log/safehome_cron.log 2>&1


Verify cron logs:

sudo tail -n 30 /var/log/safehome_cron.log

🧾 Logs and Output
File	Description
/var/log/safehome.log	Main backup activity log
/var/log/safehome_cron.log	Cron job log output
/backups/*.tar.gz.gpg	Encrypted backup archives

Example:

[Sun Nov  9 00:19:41 IST 2025] Backup completed successfully (code 1): /backups/roy_backup_2025-11-09_00-19-01.tar.gz
[Sun Nov  9 00:19:46 IST 2025] Encrypted backup created: /backups/roy_backup_2025-11-09_00-19-01.tar.gz.gpg
[Sun Nov  9 00:19:48 IST 2025] Copied backup to T7 drive.
[Sun Nov  9 00:19:48 IST 2025] Old backups cleaned.
[Sun Nov  9 00:19:49 IST 2025] ✅ Backup completed successfully!

📧 Email Alerts (via msmtp)

SafeHome integrates with msmtp for Gmail relay.
Setup once at /etc/msmtprc:

defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           roy100h100@gmail.com
user           roy100h100@gmail.com
passwordeval   cat /etc/msmtp_pass

account default : gmail


Then create the password file:

sudo nano /etc/msmtp_pass


Inside it:

your_app_password_here


and lock it down:

sudo chmod 600 /etc/msmtp_pass

🧩 Troubleshooting

If you see mail: cannot send message, check:

cat /var/log/msmtp.log


If you see Failed to execute child process “dbus-launch”, install:

sudo apt install dbus-x11 libnotify-bin

✅ Security Notes

Only the public key is used by the system (safe for automation).

Private key is stored offline, used only for decryption.

Email credentials are isolated in /etc/msmtp_pass (root-only).

Cron runs under root privileges — logs track every action.

🧰 Manual Run

To test manually:

sudo bash /home/roy/Projects/linux-admin-projects/SafeHome/safehome.sh
sudo tail -n 30 /var/log/safehome.log


SafeHome provides a reliable, end-to-end encrypted backup workflow for Linux servers and workstations — ideal for integrating into larger DevSecOps automation suites like SysEye and LogHunter.


---

Once you’ve pasted and saved that file:  

```bash
cd /home/roy/Projects/linux-admin-projects/SafeHome
git add README.md
git commit -m "Add full SafeHome documentation (encryption, cron, email setup)"
git push origin main
