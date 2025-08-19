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
# Done: Go to a system where functions are hosted in PDS repo.
# Fetch PDS functions
function fetch_functions {
    local repo_base="https://raw.githubusercontent.com/michielvha/PDS/main/bash/module"
    local tmp_dir="/tmp/PDS/module"

    # Create a temporary directory if it doesn't exist
    mkdir -p "$tmp_dir"

    # List of function files to fetch
    local files=("install.sh" "sysadmin.sh")

    # Download each file and source it
    for file in "${files[@]}"; do
        local url="$repo_base/$file"
        local local_file="$tmp_dir/$file"

        echo "Fetching $url..."
        curl -fsSL "$url" -o "$local_file"

        # Check if the file was downloaded successfully
        if [[ -s "$local_file" ]]; then
            source "$local_file"
            echo "Sourced: $local_file"
        else
            echo "Failed to fetch: $url"
        fi
    done
}
fetch_functions

# or use online
# source <(curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh")


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
# vars for custom motd message
MOTD_DIR="/etc/update-motd.d"
BACKUP_DIR="/etc/update-motd.d/backup"
CUSTOM_SCRIPT="${MOTD_DIR}/00-mikeshop"
#vars for user config
USER_NAME="sysadmin"  # Replace with the admins username you want to create
# generate key on main tooling server with `ssh-keygen -t ed25519 -C sysadmin@whatever.com` "
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuz/p0uJEULyptuR7US4GnGmCziaKLQsxYO5VyAx+Oa sysadmin@mvha.eu.org"  # Replace with your actual public key
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

# Configure Custom MOTD
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
neofetch
EOF
# Make the new MOTD script executable
sudo chmod +x $CUSTOM_SCRIPT
echo "Neofetch has been set as the MOTD. Backup of old scripts is in $BACKUP_DIR." >> $LOG

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

install_zi(){
  # install zi - a package manager for zsh.
    sudo mkdir -p /usr/local/share/zi
    sudo mkdir -p /.config/zi
    sudo git clone --depth=1 https://github.com/z-shell/zi /usr/local/share/zi
}
install_zi

# this configures zsh for all new users, first create this config then create the new user. Point it to global config.
cat <<EOF | sudo tee /etc/skel/.zshrc
source /etc/zshrc
EOF

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
function restricted_security_profile() {
  # Disable password authentication and root login, enable public key authentication.
  sudo sed -i -E '
      s/^#?PasswordAuthentication yes/PasswordAuthentication no/
      s/^#?PermitRootLogin prohibit-password/PermitRootLogin no/
      s/^#?PubkeyAuthentication yes/PubkeyAuthentication yes/
  ' /etc/ssh/sshd_config
    # Don't restart service here, should only be applied after provisioning process will be persisted when rebooting.
}
restricted_security_profile


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
  echo "==> Adding sourcing of pds main functions for $USER_NAME."
  echo "source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh)" >> /home/"$USER_NAME"/.bashrc
  echo "User $USER_NAME created, SSH key added, user added to sudo group and bashrc modified." >> $LOG
}
configure_admin

# ! MOVED TO PDS !
set_sudo_nopasswd() {
    local user="$1"
    local sudoers_file="/etc/sudoers.d/$user"

    if [[ -z "$user" ]]; then
        echo "Usage: set_sudo_nopasswd <username>"
        return 1
    fi

    if ! id "$user" &>/dev/null; then
        echo "User '$user' does not exist."
        return 2
    fi

    echo "$user ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" > /dev/null

    sudo chmod 0440 "$sudoers_file"
    echo "Passwordless sudo enabled for $user."
}
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

# TODO: add tailscale bootstrap ?

# ---

# configure grub


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

# Rework from here, add below section

# z-shell setup
# install zi ( package manager for zsh )
#git clone --depth=1 https://github.com/z-shell/zi.git $ZI_HOME/bin
#sh -c "$(curl -fsSL get.zshell.dev)" --
#chown -R ubuntu:ubuntu /home/ubuntu/.zi
#chown -R ubuntu:ubuntu /home/ubuntu/.zshrc
#cat /home/ubuntu/.zshrc
##source /home/ubuntu/.zshrc
#
#
#cat <<EOF | sudo tee -a /home/ubuntu/.zshrc
## Initialize zi
## zi init
#
## Load plugins
#zi load romkatv/powerlevel10k
#zi load zsh-users/zsh-syntax-highlighting
#zi load zsh-users/zsh-autosuggestions
#
## update
## zi update
#EOF



## set as default shell
#sudo chsh -s "$(which zsh)"


# first create file with ascii art generator then use this command to convert to login script
# echo '#!/bin/bash'; while IFS= read -r line; do echo "echo '$line'"; done < filename > mymotd.sh
# afterwards copy the content to motd section of script


## set zsh path to sysadmin user home
#export ZSH_CUSTOM="/home/$USER_NAME/.oh-my-zsh/custom"
#git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
#
##git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k # this will install the theme to /etc/oh-my-zsh/custom/themes/powerlevel10k
#function setZSH() {
#    echo "Setting up zsh for user $USER_NAME..." >> $LOG
#    echo "Copying .zshrc and .p10k.zsh to /home/$USER_NAME..." >> $LOG
#    mv /home/ubuntu/.zshrc /home/$USER_NAME/.zshrc
#    mv /home/ubuntu/.p10k.zsh /home/$USER_NAME/.p10k.zsh
#}
#setZSH

# for all users by default. This will be the system-wide zshrc file.
# moved to providing file via packer.
#cat <<EOF | sudo tee /etc/zshrc
#source /usr/local/share/zi/zi.zsh
#zi light romkatv/powerlevel10k
#zi light zsh-users/zsh-syntax-highlighting
#zi light zsh-users/zsh-autosuggestions
#zi light zsh-users/zsh-history-substring-search
#zi light agkozak/zsh-z
#
## Installs stuff in ~/zi/plugins that needs to be manually sourced so light is used each time.
#zi light ohmyzsh/ohmyzsh
#zi snippet OMZP::docker
#zi snippet OMZP::history
#source "$HOME/.zi/plugins/ohmyzsh---ohmyzsh/plugins/git/git.plugin.zsh"
#
#zi light marlonrichert/zsh-autocomplete
#zstyle ':autocomplete:*' default-context history-incremental-search-backward
#zstyle ':autocomplete:*' min-input 1
#setopt HIST_FIND_NO_DUPS
#EOF

#cat <<EOF | sudo tee /etc/zshrc
#export ZI_HOME="/usr/local/share/zi"
#source $ZI_HOME/zi.zsh
## Load plugins (pre-installed, so no install happens)
#zi load romkatv/powerlevel10k
#zi load zsh-users/zsh-syntax-highlighting
#zi load zsh-users/zsh-autosuggestions
#zi load zsh-users/zsh-history-substring-search
#zi load agkozak/zsh-z
#
## Installs stuff in ~/zi/plugins that needs to be manually sourced so light is used each time.
#zi light ohmyzsh/ohmyzsh
#zi snippet OMZP::docker
#zi snippet OMZP::history
#source "$HOME/.zi/plugins/ohmyzsh---ohmyzsh/plugins/git/git.plugin.zsh"
#
#zi load marlonrichert/zsh-autocomplete
#zstyle ':autocomplete:*' default-context history-incremental-search-backward
#zstyle ':autocomplete:*' min-input 1
#setopt HIST_FIND_NO_DUPS
#EOF

## run 1 time to install
#export ZI_HOME="/usr/local/share/zi"
#source $ZI_HOME/zi.zsh #TODO: stuck here because zi needs to run in zsh, check if we really need the light/load split or if we can just use light in default config.
## Install the plugins
#zi light romkatv/powerlevel10k
#zi light zsh-users/zsh-syntax-highlighting
#zi light zsh-users/zsh-autosuggestions
#zi light zsh-users/zsh-history-substring-search
#zi light agkozak/zsh-z
#zi light ohmyzsh/ohmyzsh
#zi light marlonrichert/zsh-autocomplete


#DONE: For replicating the p10k file the following needs to be added to /etc/zshrc, the file also needs to be copied to the host.
## Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
## Initialization code that may require console input (password prompts, [y/n]
## confirmations, etc.) must go above this block; everything else may go below.
#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi
## To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
#[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# DONE: maybe add a global location here not relative to user path for easier provisioning. like /etc/p10k/.p10k.zsh
