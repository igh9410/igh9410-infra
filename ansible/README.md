# Ansible Storage Expansion

This directory contains Ansible playbooks and configuration for expanding storage on K3s cluster VMs using password authentication, encrypted credentials, and the official **community.general.lvol module**.

## Overview

This setup uses the [community.general.lvol module](https://docs.ansible.com/ansible/latest/collections/community/general/lvol_module.html) which is the official and recommended way to manage LVM logical volumes in Ansible. The module provides:

- Safe LVM operations with built-in error handling
- Automatic filesystem resizing with `resizefs: true`
- Idempotent operations (can be run multiple times safely)
- Support for extending volumes to use all available space with `size: +100%FREE`

## Setup

### Prerequisites
- Ansible installed on your control machine
- `community.general` collection (automatically installed from requirements.yml)
- Access to the target VMs with SSH password authentication

### Configuration

The setup uses Ansible Vault to securely store SSH credentials:

1. **Encrypted Variables**: Located in `group_vars/all.yml`
   - SSH username and password
   - Sudo password (same as SSH password)

2. **Inventory**: `inventory.yml`
   - Defines all K3s cluster hosts
   - Uses encrypted variables for authentication
   - Configured for password-based SSH authentication

3. **Collections**: `requirements.yml`
   - Defines required Ansible collections and versions
   - Ensures community.general collection is available

## Usage

### Running the Storage Expansion

Execute the setup script:
```bash
./setup-and-run.sh
```

You will be prompted for the ansible-vault password multiple times during execution.

### Manual Commands

If you prefer to run commands manually:

```bash
# Install collections
ansible-galaxy collection install -r requirements.yml

# Test connectivity
ansible all -i inventory.yml -m ping --ask-vault-pass

# Run the storage expansion playbook
ansible-playbook -i inventory.yml playbooks/expand-storage.yml -v --ask-vault-pass

# Check storage status
ansible all -i inventory.yml -m shell -a "df -h /" --ask-vault-pass
```

### Managing Encrypted Variables

To edit the encrypted variables:
```bash
ansible-vault edit group_vars/all.yml
```

To view the encrypted file:
```bash
ansible-vault view group_vars/all.yml
```

To change the vault password:
```bash
ansible-vault rekey group_vars/all.yml
```

## Technical Details

### LVM Operations

The playbook uses the [community.general.lvol module](https://docs.ansible.com/ansible/latest/collections/community/general/lvol_module.html) which provides:

- **Safe Extension**: Uses `size: +100%FREE` to extend LV to use all available space
- **Automatic Filesystem Resize**: `resizefs: true` automatically resizes ext2/3/4, XFS, and ReiserFS filesystems
- **Idempotency**: Can be run multiple times without issues
- **Error Handling**: Built-in safeguards prevent data loss

### Storage Expansion Process

1. **Scan for new disk space**: Rescans SCSI devices to detect expanded storage
2. **Resize physical volume**: Expands PV to use all available disk space
3. **Extend logical volume**: Uses community.general.lvol to extend LV with all free space
4. **Resize filesystem**: Automatically resizes the filesystem to match the LV size

### Current Credentials
- **Username**: ubuntu
- **Password**: 507882 (encrypted in vault)
- **Sudo**: Uses same password, no NOPASSWD configured

### Target Hosts
- k3s-server: 192.168.45.199
- k3s-worker-1: 192.168.45.201
- k3s-worker-2: 192.168.45.202
- k3s-worker-3: 192.168.45.203
- k3s-worker-4: 192.168.45.204
- k3s-worker-5: 192.168.45.205

### Storage Configuration
- **Volume Group**: ubuntu-vg
- **Logical Volume**: ubuntu-lv
- **Operation**: Expands LV to use 100% of available space in VG
- **Filesystem**: Automatically detects and resizes supported filesystems

## Advantages of Using community.general.lvol

1. **Official Support**: Part of the official Ansible community collection
2. **Battle-tested**: Widely used and thoroughly tested in production environments
3. **Safety**: Built-in safeguards prevent accidental data loss
4. **Comprehensive**: Supports all LVM operations with proper error handling
5. **Documentation**: Well-documented with extensive examples
6. **Maintenance**: Actively maintained by the Ansible community

## Security Notes

- All sensitive credentials are encrypted using Ansible Vault
- SSH host key checking is disabled (`StrictHostKeyChecking=no`)
- The vault password should be kept secure and not committed to version control
- Consider using `--vault-password-file` for automated environments

## Troubleshooting

### Common Issues

1. **Authentication failures**: Verify the vault password and credentials
2. **Connection timeouts**: Check network connectivity to target hosts
3. **LVM errors**: Ensure the VMs have LVM configured with the expected volume names
4. **Collection not found**: Run `ansible-galaxy collection install -r requirements.yml`

### Debug Mode

Run with extra verbosity:
```bash
ansible-playbook -i inventory.yml playbooks/expand-storage.yml -vvv --ask-vault-pass
```

### Checking Collection Status

Verify community.general collection is installed:
```bash
ansible-galaxy collection list community.general
``` 