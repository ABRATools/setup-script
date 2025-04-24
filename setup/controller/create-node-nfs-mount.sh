#!/bin/bash

NODE_HOSTNAME=$1

pretty_print() {
  echo -e "\n\033[1;32m$1\033[0m"
}

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

read SUBNET MASK < <(get_subnet_and_mask)

echo "\n/var/log/${NODE_HOSTNAME}     ${SUBNET}/${MASK}(ro,async,no_root_squash,crossmnt,no_subtree_check)\n" >> /etc/exports

pretty_print "Exporting NFS share..."
exportfs -a