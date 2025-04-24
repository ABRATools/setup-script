controller="10.0.1.1"

dnf install oci-seccomp-bpf-hook
podman run --annotation io.containers.trace-syscall=of:/tmp/ls.json almalinux:latest ls / >/dev/null
podman run --security-opt seccomp=/tmp/ls.json almalinux:latest ls / >/dev/null

mkdir /var/log/abra
mount -t nfs ${controller}:/abra /var/log/abra
mkdir -p /etc/abra/images
mount -t nfs ${controller}:/images /etc/abra/images

#create abra user
#copy abra ssh key from /etc/abra/images
