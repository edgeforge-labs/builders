#!/bin/bash -eux
# Configuration Management Script:
# This script is used to configure the instance after the cloud-init process has completed.

# -- Shell Config --
# Redirect stderr to stdout for the entire script, this will get rid of most of the red in my terminal because in Packer,
# the output from the script section (provisioners) is shown in red because it's directed to stderr, which Packer highlights in red.
exec 2>&1
# Enable extended globbing
shopt -s extglob

# TODO: check for internet or provide some local way to pull the module.
# TODO: Add static ip configuration, maybe handle in cloud-init ? or check to handle on firewall/network level with static dhcp lease / dns.



# Fetch PDS functions
# TODO: Rework fetching the functions to using the pds apt package



# --  Environment Variables  --
# set var to log path
LOG="/var/log/bootstrap.log"
# Detect architecture (arm, x86, etc) used in hostname generation
ARCH=$(uname -m)
ARCH=${ARCH:0:3} # keep only the first 3 characters.
# fetch vars for hostname generation from file created during cloud-init
source /etc/profile.d/hostname_vars.sh
DOMAIN_NAME="mvha.local" # if you set tailscale domain name (main-x86-prd-01.tail6948f.ts.net) here rke2 will think tailscale is the internal network.
NEW_HOSTNAME="${ROLE}-${ARCH}-${ENV}-${COUNTER}.${DOMAIN_NAME}"

#vars for user config
USER_NAME="sysadmin"  # Replace with the admins username you want to create
# generate key on main tooling server with `ssh-keygen -t ed25519 -C sysadmin@whatever.com` "
SSH_PUBLIC_KEY="<your_ssh_public_key>"  # Replace with your actual public key
# zi env vars
#export HOME=/home/ubuntu
#export ZDOTDIR=$HOME
#export ZI_HOME=$HOME/.zi

# -- Main Script Section --
# wait until cloud-init config has been completed
echo "==> Waiting for Cloud-Init to finish..."
cloud-init status --wait
echo "Cloud-Init finished."


# Configure hostname via variables supplied in the user-data file during the cloud init process.
# TODO: Turn into function and move to PDS
if [ -n "$NEW_HOSTNAME" ]; then
  echo "new hostname detected: $NEW_HOSTNAME" >> $LOG
  # Set the hostname
  hostnamectl set-hostname "$NEW_HOSTNAME"
  # Update /etc/hosts
  sed -i "s/default-hostname/$NEW_HOSTNAME/g" /etc/hosts
  echo "Hostname set to: $NEW_HOSTNAME" >> $LOG
else
  echo "The variable for hostname generation was empty. Cannot set hostname" >> $LOG
fi

# -- Configure Custom MOTD --
# TODO: Turn into function and move to PDS
# vars for custom motd message
MOTD_DIR="/etc/update-motd.d"
BACKUP_DIR="/etc/update-motd.d/backup"
CUSTOM_SCRIPT="${MOTD_DIR}/00-mikeshop"
# Create a backup folder
sudo mkdir -p "$BACKUP_DIR"
# Check if there are files in the MOTD directory, excluding the backup directory, and move them
if ls -A "$MOTD_DIR" | grep -q -v 'backup'; then
    echo "Backing up existing MOTD scripts to $BACKUP_DIR..."
    sudo mv "$MOTD_DIR"/!(backup) "$BACKUP_DIR"/
else
    echo "No existing MOTD scripts to back up."
fi
# Create a custom neofetch MOTD script
echo "Setting up neofetch as the new MOTD..."
cat <<EOF | sudo tee $CUSTOM_SCRIPT
#!/bin/bash

echo ' ______    _             ______                     '
echo '|  ____|  | |           |  ____|                    '
echo '| |__   __| | __ _  ___ | |__ ___  _ __ __ _  ___   '
echo '|  __| / _\` |/ _\` |/ _ \|  __/ _ \| \`__/ _\` |/ _ \  '
echo '| |___| (_| | (_| |  __/| | | (_) | | | (_| |  __/  '
echo '|______\__,_|\__, |\___||_|  \___/|_|  \__, |\___|  '
echo '              __/ |                     __/ |       '
echo '             |___/                     |___/        '
echo ' '

neofetch
EOF

# Make the new MOTD script executable
sudo chmod +x $CUSTOM_SCRIPT
echo "Custom MOTD has been configured. Backup of old scripts is in $BACKUP_DIR." >> $LOG

# ============================================
# Section: Shell Configuration
# This section will configure ZSH and install required plugins.
# - Install Zi to configure:
#   - `powerlevel10k` theme | A fast reimplementation of Powerlevel9k ZSH theme.
#   - `zsh-syntax-highlighting` | Fish shell-like syntax highlighting for Zsh.
#   - `zsh-autosuggestions` | Fish shell-like autosuggestions for Zsh.
#   - `zsh-history-substring-search` | Fish shell-like history substring search for Zsh.
#   - `zsh-z` | Jump quickly to directories that you have visited "frecently."
#   - `ohmyzsh` | A delightful community-driven (with 1500+ contributors) framework for managing your Zsh configuration.
#   - `zsh-autocomplete` | A fast and efficient autocomplete plugin for Zsh.
# - Set Zsh as the Default Shell for All New Users
# - Configure global .zshrc file in /etc/zshrc
# - Configure default file for new users in /etc/skel/.zshrc referencing /etc/zshrc.
# ============================================

install_zi
configure_zsh

# Set Zsh as the Default Shell for All New Users
sudo sed -i 's|^SHELL=.*|SHELL=/bin/zsh|' /etc/default/useradd
# apply to all existing users
#for user in $(awk -F: '{if ($3 >= 1000) print $1}' /etc/passwd); do
#    sudo chsh -s /bin/zsh "$user"
#done

# ============================================
# Section: Security Hardening
# This section contains various configurations related to security hardening.
# - Disable password authentication and root login
# - Fail2Ban
# - UFW
# - Create system-wide Crontab to auto update system every night at midnight.
# ============================================
restricted_ssh_security_profile

configure_admin (){
  # Create the user and set the public key for SSH authentication
  echo "==> Creating user and setting up SSH public key..."
  sudo useradd -m -s /bin/bash "$USER_NAME" #TODO: change to zsh ?
  sudo mkdir -p /home/"$USER_NAME"/.ssh
  echo "$SSH_PUBLIC_KEY" | sudo tee /home/"$USER_NAME"/.ssh/authorized_keys
  sudo chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"/.ssh
  sudo chmod 700 /home/"$USER_NAME"/.ssh
  sudo chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
  # Add the user to the sudo group
  echo "==> Adding $USER_NAME to the sudo group..."
  sudo usermod -aG sudo "$USER_NAME"
  echo "User $USER_NAME created, SSH key added, user added to sudo group." >> $LOG
}
configure_admin

set_sudo_nopasswd $USER_NAME

## TODO: Setup Fail2Ban, edit rules in `/etc/fail2ban/jail.local`
#sudo apt install fail2ban
#sudo systemctl enable --now fail2ban
#
## TODO: Enable UFW (Uncomplicated Firewall)
#sudo ufw default deny incoming
#sudo ufw default allow outgoing
#sudo ufw allow 22/tcp  # Or custom SSH port
#sudo ufw enable


# Create system-wide Crontab to auto update system every night at midnight. imported from ``sysadmin.sh``
update_system_cron_entry

# ============================================
# Section: Tools installation
# This section contains any extra tooling required.
# - kubectl
# ============================================
install_kubectl


# add netplan config to set DHCP on all physical (starting with "en") interfaces ?
# https://www.reddit.com/r/linux4noobs/comments/bcamvx/how_to_use_wildcards_in_netplan_configuration_file/
cat <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
# https://netplan.readthedocs.io/en/latest/netplan-yaml/
network:
  version: 2
  ethernets:
    all-eth-devices:
      match:
        name: en*
      dhcp4: true
      optional: true
EOF
chmod 600 /etc/netplan/00-installer-config.yaml

# ---

# configure grub so the image becomes bootable

# Ensure EFI partition is mounted
if ! mount | grep -q '/boot/efi'; then
    EFI_PART=$(blkid | grep EFI | cut -d: -f1)
    echo "Mounting EFI partition ($EFI_PART)..."
    mount "$EFI_PART" /boot/efi
fi

# UEFI GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
  --boot-directory=/boot --removable --no-nvram --recheck

# BIOS GRUB - auto-detect disk
ROOT_DEV=$(findmnt / -o SOURCE -n | sed -E 's/[0-9]+$//; s/p[0-9]+$//')
echo "Installing BIOS GRUB to $ROOT_DEV ..."
grub-install --target=i386-pc --boot-directory=/boot "$ROOT_DEV"

# Update GRUB config
update-grub