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

add-apt-repository ppa:heyarje/makemkv-beta
apt-get update
apt-get install -y cifs-utils keyutils curl git python3 python3-pip python3-venv ffmpeg abcde handbrake-cli nginx supervisor makemkv-bin makemkv-oss

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

echo "//${SMB_SERVER}/${SMB_SHARE} ${SMB_MOUNT} cifs credentials=/etc/samba-credentials/arm,uid=arm,gid=arm,file_mode=0664,dir_mode=0775,vers=3.0,sec=ntlmssp,nofail,_netdev 0 0" >> /etc/fstab

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

echo "Installing ARM native app..."

apt-get install -y \
  lsscsi sg3-utils eject udev \
  libssl-dev libffi-dev build-essential \
  libcurl4-openssl-dev libxml2-dev libxslt1-dev zlib1g-dev \
  nginx supervisor

cd /opt

if [ ! -d /opt/automatic-ripping-machine ]; then
  git clone https://github.com/automatic-ripping-machine/automatic-ripping-machine.git
fi

cd /opt/automatic-ripping-machine

if [ -f scripts/installers/DebianInstaller.sh ]; then
  chmod +x scripts/installers/DebianInstaller.sh
  ./scripts/installers/DebianInstaller.sh
else
  echo "ERROR: DebianInstaller.sh not found."
  ls -la
  exit 1
fi

echo "Checking ARM services and ports..."
systemctl status nginx --no-pager || true
systemctl status supervisor --no-pager || true
ss -tlnp | grep -E ':80|:8080' || true
EOF

echo "Bootstrap complete for ${VM_IP}"