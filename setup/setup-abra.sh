#!/bin/bash
# Authors: A.B.R.A
# https://github.com/ABRATools/ABRA

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
TITLE="Select Node Type"
MENU="Choose one of the following options:"

OPTIONS=(
         1 "Controller"
         2 "Worker"
         3 "Exit"
        )

set -e

function header_info {
  clear
  cat <<"EOF"
   _____ ____________________    _____   
  /  _  \\______   \______   \  /  _  \  
 /  /_\  \|    |  _/|       _/ /  /_\  \ 
/    |    \    |   \|    |   \/    |    \
\____|__  /______  /|____|_  /\____|__  /
        \/       \/        \/         \/ 

EOF
}
header_info

HOSTNAME=$(hostname)

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi
if ! grep -q "AlmaLinux release 9.5 (Teal Serval)" /etc/redhat-release; then
  echo "Error: This script is intended for AlmaLinux." >&2
  exit 1
fi

pretty_print() {
  echo -e "\n\033[1;32m$1\033[0m"
}
pretty_print "Starting ABRA setup script..."
# check if go exists
if ! [ -x "$(command -v go)" ]; then
  echo 'Error: go is not installed.' >&2
  echo "Install the latest version of Go from the official website!"
  exit 1
fi

pretty_print "Updating system..."

# Update the system
sudo dnf --refresh update -y
sudo dnf upgrade -y --skip-broken

pretty_print "Installing Docker..."

# Add Docker repository
sudo dnf install yum-utils -y
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# Install Docker
sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
# Start and enable Docker
sudo systemctl enable --now docker
sudo systemctl start docker

# Install the SIG RPM key.
sudo rpm --import https://www.centos.org/keys/RPM-GPG-KEY-CentOS-SIG-Kmods
# Install the repository.
cat > /etc/yum.repos.d/centos-kmods-kernel-latest.repo <<'EOF'
[centos-kmods-kernel-latest-repos]
name=CentOS $releasever - Kmods - Kernel Latest - Repositories
metalink=https://mirrors.centos.org/metalink?repo=centos-kmods-sig-kernel-latest-$releasever&arch=$basearch&protocol=https,http
#baseurl=http://mirror.stream.centos.org/SIGs/$releasever/kmods/$basearch/kernel-latest
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Kmods
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1
EOF
# Update the kernel to the latest from the repository added.
dnf update

pretty_print "Installing Podman..."

# Install Podman build dependencies
sudo dnf -y install 'dnf-command(builddep)'
dnf config-manager --set-enabled crb
# Install Podman build dependencies
sudo dnf -y install epel-release
sudo dnf -y gcc glib2-devel glibc-devel glibc-static golang git-core go-rpm-macros gpgme-devel libassuan-devel libgpg-error-devel libseccomp-devel libselinux-devel shadow-utils-subid-devel pkgconfig make man-db ostree-devel systemd systemd-devel
# Install Podman runtime dependencies
sudo dnf -y install conmon containers-common crun iptables netavark nftables slirp4netns btrfs-progs btrfs-progs-devel pgpme-devel libassuan libgpg-error libseccomp libselinux shadow-utils
# Install Podman
sudo dnf install -y podman git nfs-utils

pretty_print "Installing Python..."

sudo dnf install -y python3 python3-pip python3-devel python3-venv

CHOICE=$(dialog --clear --title "$TITLE" --menu "$MENU" $HEIGHT $WIDTH $CHOICE_HEIGHT  "${OPTIONS[@]}" 2>&1 >/dev/tty)
clear

case $CHOICE in
  1)
    pretty_print "Setting up ABRA as a controller..."
    source ./controller/setup-controller.sh
    ;;
  2)
    pretty_print "Setting up the ABRA node agent..."
    source ./compute/setup-node.sh
    ;;
  3)
    pretty_print "Exiting"
    exit
    ;;
esac

