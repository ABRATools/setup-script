#!/bin/bash

set -eoux pipefail

HOSTNAME=$(hostname)
INSTALLATION_DIR='/opt/ABRA-nodeapi'
SERVICE_PATH=/etc/systemd/system/abra-node-agent.service
AFTER=${AFTER:-"network.target"}
DESCRIPTION=${DESCRIPTION:-"ABRA Node Agent"}
WORKDIR=${WORKDIR:-"$INSTALLATION_DIR"}
EXEC_BIN=${EXEC_BIN:-"$WORKDIR/abra-nodeapi"}
EXEC_STOP=${EXEC_STOP:-"/usr/bin/kill -HUP \$MAINPID"}
INSTALL_TARGET=${INSTALL_TARGET:-"multi-user.target"}

TITLE="ABRA Node Setup"
HEIGHT=10; WIDTH=40; FIELD_HEIGHT=1

git clone https://github.com/ABRATools/go-nodeapi.git --depth 1 --branch main $INSTALLATION_DIR

cd INSTALLATION_DIR

go mod tidy
go build -o abra-nodeapi ./cmd/go-api/main.go

cd -

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=$DESCRIPTION
After=$AFTER

[Service]
Type=simple
WorkingDirectory=$WORKDIR
ExecStart=$EXEC_BIN
ExecStop=$EXEC_STOP

[Install]
WantedBy=$INSTALL_TARGET
EOF

echo "Wrote unit to $SERVICE_PATH"
echo "Reloading systemd daemon…"
systemctl daemon-reload

CONTROLLER_IP=$(dialog --clear \
  --title "$TITLE" \
  --inputbox "Enter the IP address of the ABRA controller:" \
  $HEIGHT $WIDTH "" \
  2>&1 >/dev/tty)

CONTROLLER_HOSTNAME=$(dialog --clear \
  --title "$TITLE" \
  --inputbox "Enter the hostname of the ABRA controller:" \
  $HEIGHT $WIDTH "" \
  2>&1 >/dev/tty)

clear

dnf install -y oci-seccomp-bpf-hook
dnf install -y nfs-utils

mkdir /var/log/${HOSTNAME}
mount -t nfs ${CONTROLLER_IP}:/var/log/${HOSTNAME} /var/log/${HOSTNAME}
mkdir -p /etc/abra/images
mount -t nfs ${CONTROLLER_IP}:/images /etc/abra/images

systemctl enable abra-node-agent.service
systemctl start abra-node-agent.service
systemctl status abra-node-agent.service