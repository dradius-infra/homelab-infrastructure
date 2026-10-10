#!/usr/bin/env bash
# ==============================================================================
# Description   : Automated, local-first MikroTik RouterOS Git backup script
# Architecture  : Proxmox LXC -> SSH (Ed25519, Read-Only) -> Git Version Control
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# CONFIGURATION 
# ------------------------------------------------------------------------------
ROUTER_IP="${ROUTER_IP:-192.0.2.1}"              # RFC 5737 Test IP
ROUTER_USER="${ROUTER_USER:-backup-bot}"          # Read-only user
SSH_KEY="${SSH_KEY:-/home/user/.ssh/id_ed25519}" # Ed25519 private key path
REPO_DIR="${REPO_DIR:-/opt/router-backup}"       # Local Git repository path

BACKUP_FILE="${REPO_DIR}/router-config.rsc"
TEMP_FILE="${REPO_DIR}/router-config.rsc.tmp"

# Ensure target directory exists and switch into it
mkdir -p "${REPO_DIR}"
cd "${REPO_DIR}"

# 1. Fetch sanitized configuration from MikroTik via SSH
ssh -i "${SSH_KEY}" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    "${ROUTER_USER}@${ROUTER_IP}" "/export" > "${TEMP_FILE}"

# 2. Strip volatile dynamic header lines to prevent false-positive diffs
sed -i '/^#.*by RouterOS/d' "${TEMP_FILE}"
sed -i '/^# software id/d' "${TEMP_FILE}"

# 3. Handle initial baseline snapshot
if [ ! -f "${BACKUP_FILE}" ]; then
    mv "${TEMP_FILE}" "${BACKUP_FILE}"
    git add "${BACKUP_FILE}"
    git commit -m "chore(backup): initial configuration baseline"
    echo "[+] Initial snapshot created and committed."
    exit 0
fi

# 4. Compare existing snapshot with newly fetched export
if cmp -s "${BACKUP_FILE}" "${TEMP_FILE}"; then
    rm -f "${TEMP_FILE}"
    echo "[-] No configuration changes detected."
    exit 0
else
    mv "${TEMP_FILE}" "${BACKUP_FILE}"
    git add "${BACKUP_FILE}"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    git commit -m "backup: configuration update detected (${TIMESTAMP})"
    echo "[+] Configuration changed. New commit created at ${TIMESTAMP}."
    exit 0
fi
