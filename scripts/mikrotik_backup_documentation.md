# MikroTik RouterOS Automated Git Backup & Change Detection

An automated, local-first configuration backup and version-controlled change detection engine for MikroTik RouterOS v7 using Bash, SSH key authentication, and Git on a Linux host.

---

## 1. Overview & Architecture

The objective of this project is to implement an automated configuration tracking pipeline without relying on external cloud services. The automation agent queries the network router, validates configuration integrity, and commits changes to a local Git repository only when meaningful configuration differences are detected.

### Repository Architecture Separation
To maintain high security and avoid structural conflicts:
* **Public Repository (Tooling & Documentation):** Hosts the sanitized automation script and documentation. Contains a strict `.gitignore` to prevent any configuration state (`*.rsc`) from leaking publicly.
* **Local/Private Instance (Operational Backups):** Runs on-premises within the Linux automation host. In this dedicated local environment, Git tracks the actual `router-config.rsc` baseline while remaining completely air-gapped from external Git remotes.

### Operational Data Flow
1. **Scheduled Execution:** Cron triggers the backup runner at a scheduled interval.
2. **Secure SSH Fetch:** The host connects to RouterOS via SSH using an Ed25519 key bound to a dedicated read-only service account.
3. **Export Extraction:** A configuration export is written to an isolated temporary file.
4. **Header Sanitization:** Dynamic metadata headers (RouterOS timestamps and software build identifiers) are removed via `sed` to eliminate false-positive diffs.
5. **Change Detection:** A byte-by-byte binary comparison (`cmp -s`) checks the new export against the existing baseline.
6. **Git Version Control:** If differences exist, the new state is committed locally with a timestamp. If identical, the execution exits cleanly.

---

## 2. Security Hardening & Threat Model

* **Principle of Least Privilege:** The router service account belongs strictly to the `read` policy group. If the automation host is compromised, the key cannot be used to modify network state, alter firewall filters, or execute administrative commands.
* **Modern Cryptography:** Authentication relies on an elliptic-curve **Ed25519** keypair instead of legacy RSA.
* **Idempotency:** Automated commits are only registered when an actual configuration change is detected, preventing repository bloat.
* **Strict Host Key Pinning:** SSH connections must use pinned host keys (`StrictHostKeyChecking=yes`) to prevent Man-in-the-Middle (MITM) attacks within the management network.

---

## 3. RouterOS Configuration (v7)

Create a dedicated read-only user and import the public key:

```routeros
# Create service account restricted to the read-only policy group
/user add name=backup-bot group=read

# Associate the automation public key with the account
/user ssh-keys import public-key-file=id_ed25519.pub user=backup-bot
```

---

## 4. Automation Host Setup

### Prerequisites
```bash
apt update && apt install -y git openssh-client
```

### Initialize Local Version Control (Operational Host)
```bash
mkdir -p /opt/router-backup
cd /opt/router-backup
git init

# Configure identity for automated commits
git config user.name "Backup Automation Bot"
git config user.email "backup-bot@homelab.local"

# Ignore temporary artifacts and runner script from the backup baseline
echo -e "*.tmp\n*.log\nmikrotik-git-backup.sh" > .gitignore
```

### Automation Scheduling (Cron)
Add the entry via `crontab -e`:
```cron
0 3 * * * /opt/router-backup/mikrotik-git-backup.sh >> /var/log/router-backup.log 2>&1
```

---

## 5. Change Inspection & Recovery Realities

### Inspecting Change History
```bash
cd /opt/router-backup

# View concise commit history
git log --oneline

# Inspect exact line-by-line diff of the latest snapshot
git log -p -1
```

### Restoration & Disaster Recovery Guidelines

> **Important Operational Note:** A raw `/import` command in RouterOS does not perform an atomic replace. It executes commands sequentially against the existing state and will fail if duplicate identifiers, active interfaces, or conflicting IP leases are encountered.

Depending on the operational scenario, recovery must follow one of two paths:

#### Option A: Granular Reversion (Recommended for Operational Diffs)
1. Use `git diff HEAD~1` to identify the specific lines that introduced an issue.
2. Manually revert or adjust the conflicting sub-tree via Winbox or terminal (e.g., firewall rule adjustments, interface comments).

#### Option B: Full Disaster Recovery (Bare-Metal Rebuild)
1. Retrieve the validated `.rsc` baseline from the local Git history:
   ```bash
   git checkout <COMMIT_HASH> -- router-config.rsc
   ```
2. Inspect the file locally to ensure no syntax inconsistencies exist.
3. Upload the file to RouterOS storage.
4. Execute a clean reset without default configuration, applying the script post-boot:
   ```routeros
   /system reset-configuration no-defaults=yes run-after-reset=router-config.rsc
   ```