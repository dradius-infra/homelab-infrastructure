#!/usr/bin/env bash
# MikroTik RouterOS automated backup & git sync
set -uo pipefail

# Config
ROUTER_IP="${ROUTER_IP:-192.0.2.1}"
ROUTER_USER="${ROUTER_USER:-backup-bot}"
SSH_KEY="${SSH_KEY:-/home/user/.ssh/id_ed25519}"
REPO_DIR="${REPO_DIR:-/opt/router-backup}"

BACKUP_FILE="${REPO_DIR}/router-config.rsc"
TEMP_FILE="${REPO_DIR}/router-config.rsc.tmp"

mkdir -p "${REPO_DIR}"
cd "${REPO_DIR}"

# Grab router export over SSH
ssh -i "${SSH_KEY}" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    "${ROUTER_USER}@${ROUTER_IP}" "/export" > "${TEMP_FILE}"

# Strip timestamps & software ID so git diff stays clean
sed -i '/^#.*by RouterOS/d' "${TEMP_FILE}"
sed -i '/^# software id/d' "${TEMP_FILE}"

# First run: create baseline
if [ ! -f "${BACKUP_FILE}" ]; then
    mv "${TEMP_FILE}" "${BACKUP_FILE}"
    git add "${BACKUP_FILE}"
    git commit -m "chore(backup): initial configuration baseline"
    echo "[+] Initial snapshot created and committed."
    exit 0
fi

# Check for changes against previous backup
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