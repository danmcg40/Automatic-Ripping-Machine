#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/ripper.env"

: "${VM_IP:?VM_IP is required}"
: "${SSH_USER:?SSH_USER is required}"
: "${SMB_SERVER:?SMB_SERVER is required}"
: "${SMB_SHARE:?SMB_SHARE is required}"
: "${SMB_USERNAME:?SMB_USERNAME is required}"
: "${SMB_PASSWORD:?SMB_PASSWORD is required}"
: "${SMB_MOUNT:?SMB_MOUNT is required}"

SSH_OPTS="-i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

wait_for_ssh() {
  i=0
  until ssh $SSH_OPTS "${SSH_USER}@${VM_IP}" "echo ok" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
      echo "SSH did not become ready on ${VM_IP}"
      exit 1
    fi
    echo "Waiting for SSH on ${VM_IP}..."
    sleep 5
  done
}

wait_for_ssh

ssh $SSH_OPTS "${SSH_USER}@${VM_IP}" "sudo bash -s" <<EOF
set -eu

apt-get update
apt-get install -y cifs-utils keyutils curl git python3 python3-pip python3-venv ffmpeg abcde handbrake-cli

id arm >/dev/null 2>&1 || useradd -m -s /bin/bash arm

mkdir -p "${SMB_MOUNT}"
mkdir -p /etc/samba-credentials

cat > /etc/samba-credentials/arm <<CREDS
username=${SMB_USERNAME}
password=${SMB_PASSWORD}
CREDS

chmod 600 /etc/samba-credentials/arm

# Remove any old fstab line for this mount path
sed -i "\\# ${SMB_MOUNT} #d" /etc/fstab
sed -i "\\#${SMB_MOUNT}#d" /etc/fstab

echo "//${SMB_SERVER}/${SMB_SHARE} ${SMB_MOUNT} cifs credentials=/etc/samba-credentials/arm,iocharset=utf8,uid=arm,gid=arm,file_mode=0664,dir_mode=0775,vers=3.0,sec=ntlmssp,nofail,_netdev 0 0" >> /etc/fstab

echo "Testing SMB mount..."
if ! mount "${SMB_MOUNT}"; then
  echo "SMB mount failed. Recent kernel messages:"
  dmesg | tail -80
  exit 1
fi

mkdir -p "${SMB_MOUNT}/raw"
mkdir -p "${SMB_MOUNT}/completed"
mkdir -p "${SMB_MOUNT}/logs"

chown -R arm:arm "${SMB_MOUNT}/raw" "${SMB_MOUNT}/completed" "${SMB_MOUNT}/logs" || true

# Placeholder install path for ARM app
# Replace with your preferred ARM install method later.
EOF

echo "Bootstrap complete for ${VM_IP}"