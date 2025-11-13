# 🛡️ UFW Guardian v3 — Firewall Helper

UFW Guardian is a Bash script that configures and manages the UFW firewall on Linux in a safe, repeatable, and logged way.

This project is part of a personal Linux security training path.

---

## 🔧 What UFW Guardian Does

- Checks if you are **root** (must run with `sudo`).
- Ensures **UFW is enabled** (and turns it on if needed).
- Applies **secure defaults**:
  - `deny incoming`
  - `allow outgoing`
- Reads allowed ports from a config file:
  - `config/ufw_allowed_ports.conf`
- Logs all actions with timestamps to:
  - `logs/ufw_guardian.log`
- Has extra modes:
  - `--status` → show full UFW status
  - `--reset` → backup rules and reset UFW safely
  - `--add` → re-apply your rules after a reset

---

## 📁 Project Structure

```text
ufw_guardian/
├── ufw_guardian.sh               # Main script
├── config/
│   └── ufw_allowed_ports.conf    # List of allowed ports (one per line)
├── logs/
│   └── ufw_guardian.log          # Log file (auto-created)
└── backups/                      # UFW rule backups (created by --reset)
⚙️ Config File Example
config/ufw_allowed_ports.conf:

text
Copy code
22
80
443
# Add more ports here if needed
Each line is:

A port number (like 22, 80, 443)

Or a comment starting with # (ignored by the script)

🖥️ Usage
From inside the project folder:

bash
Copy code
sudo ./ufw_guardian.sh
This will:

Enable UFW if needed

Set defaults (deny incoming, allow outgoing)

Allow all ports from config/ufw_allowed_ports.conf

Log everything to logs/ufw_guardian.log

📊 Show current firewall status
bash
Copy code
sudo ./ufw_guardian.sh --status
Shows ufw status verbose

Good for checking which ports are allowed.

🧨 Reset UFW (with backup)
bash
Copy code
sudo ./ufw_guardian.sh --reset
What happens:

Backup current UFW rules into backups/

Reset UFW to defaults

You can then run the script again to re-apply your clean rules.

➕ Re-apply rules after reset
bash
Copy code
sudo ./ufw_guardian.sh --add
Re-applies the allowed ports from the config file.

Useful after --reset.

🧪 Example workflow
bash
Copy code
cd ufw_guardian
sudo ./ufw_guardian.sh           # Apply firewall rules
sudo ./ufw_guardian.sh --status  # See the status
sudo ./ufw_guardian.sh --reset   # Backup & reset UFW
sudo ./ufw_guardian.sh --add     # Re-apply allowed ports
📚 Skills Demonstrated
Bash scripting (functions, conditions, loops)

Working with UFW firewall

Log files and timestamps

Safe defaults and idempotent configuration

Basic DevSecOps mindset (automation + safety)

yaml
Copy code

---

### 3️⃣ Save and exit nano

Inside nano:

- Press `Ctrl + O` → **Write Out** (save)  
- Press `Enter` → confirm file name `README.md`  
- Press `Ctrl + X` → **Exit** nano  

Now `README.md` exists in your project.

You can check:

```bash
ls
