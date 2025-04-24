#!/bin/bash

set -eoux pipefail

HOSTNAME=$(hostname)
INSTALLATION_DIR='/opt/ABRA'
SERVICE_PATH=/etc/systemd/system/abra-main.service
DESCRIPTION=${DESCRIPTION:-"Central ABRA Service"}
WORKDIR=${WORKDIR:-"$INSTALLATION_DIR/backend"}
EXEC_BIN=${EXEC_BIN:-"$WORKDIR/venv/bin/python3"}
EXEC_SCRIPT=${EXEC_SCRIPT:-"$WORKDIR/main.py"}
EXEC_STOP=${EXEC_STOP:-"/usr/bin/kill -9 \$MAINPID"}
INSTALL_TARGET=${INSTALL_TARGET:-"multi-user.target"}

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

get_subnet_and_mask() {
    local iface network_and_mask subnet mask

    iface=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')

    network_and_mask=$(
      ipcalc -nb "$(ip -o -4 addr show dev "$iface" | awk '{print $4}')" \
      | awk '/^Network:/ {print $2}'
    )

    subnet=${network_and_mask%%/*}
    mask=${network_and_mask##*/}

    printf '%s %s' "$subnet" "$mask"
}

pretty_print() {
  echo -e "\n\033[1;32m$1\033[0m"
}

pretty_print "Installing Node Agent..."

git clone https://github.com/ABRATools/ABRA --depth 1 --branch main $INSTALLATION_DIR

cd ${INSTALLATION_DIR}/backend

python3 -m venv venv

source venv/bin/activate

python3 -m pip install -r requirements.txt

EXEC_BIN add_user.py --username admin --password abraabra --email "abra@example.com" --admin

deactivate
cd -

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=$DESCRIPTION

[Service]
Type=simple
WorkingDirectory=$WORKDIR
ExecStart=$EXEC_BIN $EXEC_SCRIPT
ExecStop=$EXEC_STOP

[Install]
WantedBy=$INSTALL_TARGET
EOF

pretty_print "Wrote unit to $SERVICE_PATH"
pretty_print "Reloading systemd daemon…"

systemctl daemon-reload

dnf install nfs-utils ipcalc -y

systemctl enable nfs-server
systemctl start nfs-server

read SUBNET MASK < <(get_subnet_and_mask)

mkdir /run/abra
mkdir -p /etc/abra/images
touch /etc/abra/active_jobs

mkdir /var/log/abra

echo "\n/etc/abra/images     ${SUBNET}/${MASK}(ro,async,no_root_squash,crossmnt,no_subtree_check)\n" >> /etc/exports
echo "\n/var/log/${HOSTNAME}     ${SUBNET}/${MASK}(ro,async,no_root_squash,crossmnt,no_subtree_check)\n" >> /etc/exports

exportfs -a

systemctl enable abra-main.service
systemctl start abra-main.service
systemctl status abra-main.service