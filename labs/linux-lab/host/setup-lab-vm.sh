#!/usr/bin/env bash
# Prepares the Linux lab VM for docs/linux-lab.
# Run INSIDE the lab VM (Ubuntu 24.04), from a clone of this repository:
#
#   bash labs/linux-lab/host/setup-lab-vm.sh
#
# It installs observability/tracing tools, a single-node k3s pinned to the main
# cluster's version, a kubeconfig whose only context is `linux-lab`, and the
# lab namespace. Safe to re-run.
set -euo pipefail

K3S_VERSION="${K3S_VERSION:-v1.34.4+k3s1}" # keep in sync with infrastructure/system-upgrade-controller/plans.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking for the unified cgroup v2 hierarchy"
if [[ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]]; then
  echo "cgroup v2 is not mounted at /sys/fs/cgroup. Use an Ubuntu 22.04+ VM." >&2
  exit 1
fi

echo "==> Installing troubleshooting, load and tracing tools"
sudo apt-get update -q
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  sysstat procps psmisc lsof strace ltrace tcpdump conntrack iproute2 \
  dnsutils iotop fio stress-ng bpftrace bpfcc-tools linux-tools-common \
  jq python3 git
# perf needs tools built for the running kernel. Some VM products ship their
# own kernel without a matching package, so this one is best effort.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "linux-tools-$(uname -r)" ||
  echo "WARN: linux-tools-$(uname -r) not available; perf will not work on this kernel"

echo "==> Enabling sysstat history (sar)"
sudo sed -i 's/^ENABLED=.*/ENABLED="true"/' /etc/default/sysstat
sudo systemctl enable --now sysstat

if ! command -v k3s >/dev/null 2>&1; then
  echo "==> Installing k3s ${K3S_VERSION} (flannel + kube-proxy defaults, no Traefik)"
  curl -sfL https://get.k3s.io |
    INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server \
      --write-kubeconfig-mode 0644 \
      --disable traefik
fi

echo "==> Waiting for the node to become Ready"
until sudo k3s kubectl get nodes >/dev/null 2>&1; do sleep 2; done
sudo k3s kubectl wait --for=condition=Ready node --all --timeout=180s

echo "==> Writing ~/.kube/config with a single context named linux-lab"
mkdir -p "${HOME}/.kube"
sudo k3s kubectl config view --raw >"${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
if kubectl config get-contexts -o name | grep -qx default; then
  kubectl config rename-context default linux-lab
fi
kubectl config use-context linux-lab

echo "==> Creating the lab namespace, LimitRange and ResourceQuota"
kubectl --context linux-lab apply -k "${SCRIPT_DIR}/../base"

echo
echo "Done. Quick checks:"
echo "  kubectl --context linux-lab get nodes"
echo "  sudo execsnoop-bpfcc    # Ctrl+C to stop"
