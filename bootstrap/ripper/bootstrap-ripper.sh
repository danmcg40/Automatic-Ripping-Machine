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

add-apt-repository ppa:heyarje/makemkv-beta -y
apt-get update
apt-get install -y cifs-utils keyutils curl git python3 python3-pip python3-venv ffmpeg abcde handbrake-cli nginx supervisor makemkv-bin makemkv-oss

echo "DEBUG: reached line before suspected failure"

id arm >/dev/null 2>&1 || useradd -m -s /bin/bash arm
usermod -aG cdrom arm

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
  echo "mount ${SMB_MOUNT} failed, trying mount -a..."
  if ! mount -a; then
    echo "SMB mount failed"
    dmesg | tail -80
    exit 1
  fi
fi

mkdir -p "${SMB_MOUNT}/raw"
mkdir -p "${SMB_MOUNT}/transcode"
mkdir -p "${SMB_MOUNT}/completed"
mkdir -p "${SMB_MOUNT}/logs"

chown -R arm:arm \
  "${SMB_MOUNT}/raw" \
  "${SMB_MOUNT}/transcode" \
  "${SMB_MOUNT}/completed" \
  "${SMB_MOUNT}/logs" || true

echo "Installing ARM native app manually..."

apt-get install -y \
  git python3-venv libcurl4-gnutls-dev gcc python3-dev libffi-dev \
  libdiscid0 handbrake-cli eject lsdvd at makemkv-bin makemkv-oss

cd /opt
rm -rf /opt/arm
git clone --recurse-submodules https://github.com/automatic-ripping-machine/automatic-ripping-machine.git /opt/arm
chown -R arm:arm /opt/arm
chmod 775 /opt/arm

cp /opt/arm/setup/51-automatic-ripping-machine-venv.rules /etc/udev/rules.d/
chmod +x /opt/arm/scripts/thickclient/arm_venv_wrapper.sh

cp /opt/arm/setup/arm.yaml /opt/arm/arm.yaml

sed -i "s#^RAW_PATH:.*#RAW_PATH: ${SMB_MOUNT}/raw#" /opt/arm/arm.yaml
sed -i "s#^TRANSCODE_PATH:.*#TRANSCODE_PATH: ${SMB_MOUNT}/transcode#" /opt/arm/arm.yaml
sed -i "s#^COMPLETED_PATH:.*#COMPLETED_PATH: ${SMB_MOUNT}/completed#" /opt/arm/arm.yaml
sed -i "s#^LOGPATH:.*#LOGPATH: ${SMB_MOUNT}/logs#" /opt/arm/arm.yaml

chown arm:arm /opt/arm/arm.yaml

mkdir -p /etc/arm/config
ln -sf /opt/arm/arm.yaml /etc/arm/config/arm.yaml
cp /opt/arm/setup/apprise.yaml /etc/arm/config/apprise.yaml
cp --no-clobber /opt/arm/setup/.abcde.conf /etc/.abcde.conf || true
chown arm:arm /etc/.abcde.conf
ln -sf /etc/.abcde.conf /etc/arm/config/abcde.conf

sudo -u arm mkdir -p /home/arm/logs/progress
sudo -u arm mkdir -p /home/arm/media/raw
sudo -u arm mkdir -p /home/arm/media/transcode
sudo -u arm mkdir -p /home/arm/media/completed

sed -i 's/^cffi==.*/cffi/' /opt/arm/arm-dependencies/requirements.txt || true
sed -i 's/^SQLAlchemy==.*/SQLAlchemy/' /opt/arm/arm-dependencies/requirements.txt || true

sudo -u arm bash -c '
cd /opt/arm
python3 -m venv venv
. venv/bin/activate
pip install --upgrade pip
pip install -r arm-dependencies/requirements.txt
'

cp /opt/arm/setup/armui.service /etc/systemd/system/armui.service

systemctl daemon-reload
systemctl enable armui
systemctl restart armui

echo "ARM configured paths:"
grep -E "RAW_PATH|TRANSCODE_PATH|COMPLETED_PATH|LOGPATH" /opt/arm/arm.yaml || true

ss -tlnp | grep -E ":80|:8080" || true
systemctl status armui --no-pager || true

EOF

echo "Bootstrap complete for ${VM_IP}"