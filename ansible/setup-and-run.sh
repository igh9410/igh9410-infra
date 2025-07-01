#!/bin/bash

# Setup and run storage expansion playbook
# This script installs required Ansible collections and runs the storage expansion playbook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="$SCRIPT_DIR/inventory.yml"
PLAYBOOK_FILE="$SCRIPT_DIR/playbooks/expand-storage.yml"

echo "=== Storage Expansion Setup and Execution ==="
echo "Script directory: $SCRIPT_DIR"
echo "Inventory file: $INVENTORY_FILE"
echo "Playbook file: $PLAYBOOK_FILE"
echo

# Check if required files exist
if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo "Error: Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

if [[ ! -f "$PLAYBOOK_FILE" ]]; then
    echo "Error: Playbook file not found: $PLAYBOOK_FILE"
    exit 1
fi

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install community.general --upgrade

echo
echo "Testing connectivity to all hosts..."
ansible all -i "$INVENTORY_FILE" -m ping

echo
echo "=== Current storage status on all hosts ==="
ansible all -i "$INVENTORY_FILE" -m shell -a "df -h / && echo '---' && lsblk" -b

echo
echo "=== Starting storage expansion playbook ==="
echo "Press Enter to continue or Ctrl+C to cancel..."
read -r

# Run the storage expansion playbook
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" -v

echo
echo "=== Storage expansion completed ==="
echo "Verifying final storage status..."
ansible all -i "$INVENTORY_FILE" -m shell -a "df -h /" -b

echo
echo "=== Summary ==="
echo "Storage expansion playbook execution completed successfully!"
echo "All VMs should now be using the full allocated SSD space." 