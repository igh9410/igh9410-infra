#!/bin/bash
export CONTROL_PLANE_IP=192.168.45.105
export WORKER_IP=("192.168.45.21" "192.168.45.225" "192.168.45.4" "192.168.45.81")

talosctl get disks --insecure --nodes 192.168.45.105
export CLUSTER_NAME=igh9410-homelab
export DISK_NAME=xvda

talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 --install-disk /dev/$DISK_NAME
talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP --file controlplane.yaml

for ip in "${WORKER_IP[@]}"; do
    echo "Applying config to worker node: $ip"
    talosctl apply-config --insecure --nodes "$ip" --file worker.yaml
done

talosctl --talosconfig=./talosconfig config endpoints $CONTROL_PLANE_IP

talosctl bootstrap --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig
