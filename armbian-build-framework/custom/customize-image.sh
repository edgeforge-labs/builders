#!/bin/bash

# this is a native solution and will run when we are building the image, so in theory we don't need to keep the ssh keys and password predictable, because packer won't need to try to reach the machine after it's booted.
# I'm more a fan of having this config be done by something like packer and only use the framework to pack the cloud-init but let's try the native solution.

# -- Shell Config --
# Enable extended globbing
shopt -s extglob


# --  Environment Variables  --


# -- Functions  --
log() {
    local log_level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S,%3N')
    echo "$timestamp - customize-image.sh[$log_level]: $message"
}

# also accept piped values with logging function
#log() {
#    local log_level=$1
#    shift
#    local message="$*"
#
#    # If data is piped, read from stdin
#    if [ ! -t 0 ]; then
#        local piped_message=$(< /dev/stdin)
#        echo "$(date '+%Y-%m-%d %H:%M:%S,%3N') - script.sh[$log_level]: $piped_message $message"
#    else
#        echo "$(date '+%Y-%m-%d %H:%M:%S,%3N') - script.sh[$log_level]: $message"
#    fi
#}


# set var to log path
LOG="/var/log/customize-script.log"
# vars for custom motd message
MOTD_DIR="/etc/update-motd.d"
BACKUP_DIR="/etc/update-motd.d/backup"
CUSTOM_SCRIPT="${MOTD_DIR}/00-edgecloud"

# -- Main Script Section --
sudo apt update -y && apt upgrade -y # && apt dist-upgrade -y # full upgrade including resolving dependencies
sudo apt install git nfs-common curl file bpytop build-essential net-tools neofetch bash-completion -y

# -- setup sysadmin user --

# Install az-cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Configure Custom MOTD
# Create a backup folder
sudo mkdir -p "$BACKUP_DIR"
# Check if there are files in the MOTD directory, excluding the backup directory, and move them
if ls -A "$MOTD_DIR" | grep -q -v 'backup'; then
    log "INFO" "Backing up existing MOTD scripts to $BACKUP_DIR..."
    sudo mv "$MOTD_DIR"/!(backup) "$BACKUP_DIR"/
else
    log "DEBUG" "No existing MOTD scripts to back up."
fi

# Create a custom neofetch MOTD script
echo "Setting up neofetch as the new MOTD..."
cat <<EOF | sudo tee $CUSTOM_SCRIPT
#!/bin/bash
neofetch
EOF
# Make the new MOTD script executable
sudo chmod +x $CUSTOM_SCRIPT
log "INFO" "Neofetch has been set as the MOTD. Backup of old scripts is in $BACKUP_DIR." >> $LOG

#  -- no longer needed since 24.11.0 --
# Enable SPI NOR Flash to hold bootloader to boot from SSD.
# These device tree overlays are only found in the vendor image. Going to manually try them on current image.
# If it doesn't work will have to revert back to vendor image. Or figure out how I can create one that matches my kernel version.

# Path to check = Old logic, rework.
#file_path="/boot/dtb/rockchip/overlay/rock-5a-spi-nor-flash.dtbo"
## Verify if the path exists
#if [ -e "$file_path" ]; then
#    log "DEBUG" "Path exists: $file_path"
#    # Append the echo statement to /boot/armbianEnv.txt
#    echo "overlays=rock-5a-spi-nor-flash" >> /boot/armbianEnv.txt
#    log "INFO" "overlays=rock-5a-spi-nor-flash appended to /boot/armbianEnv.txt"
#else
#    log "DEBUG" "Path does not exist: $file_path"
#fi

# Modify sysadmin .zshrc, moved to copying custom .zshrc file
#cat <<EOF | sudo tee /home/sysadmin/.zshrc
#neofetch
#alias knr='kubectl get pods --field-selector=status.phase!=Running'
#source <(kubectl completion bash)
#EOF


# Enable theme for zsh
# git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k # this will install the theme to /etc/oh-my-zsh/custom/themes/powerlevel10k
# TODO: After install of theme via gitclone you need to replace .p10k.zsh & .zshrc with files in custom dir of build framework, same as this script. above line also needs to be ran for the theme to be installed


## Adding Aliasses
#echo "Setting up kubectl aliases"
#cat <<EOF | sudo tee ~/.bashrc
## list all pods that are not running
#alias kgr="kubectl get pods -o wide -A | awk '{print \$1, \$2, \$4}' | grep -v Running"
## List all pods in all namespaces (wide view)
#alias kga='kubectl get pods -o wide -A'
## Get all resources in the current namespace
#alias kgall='kubectl get all'
## Quick describe pod
#alias kdp='kubectl describe pod'
## Quick delete pod
#alias kdelp='kubectl delete pod'
## View logs for a pod
#alias kl='kubectl logs'
## View logs for a pod with continuous output
#alias klf='kubectl logs -f'
## View logs of all containers in a pod
#alias klfa='kubectl logs -f --all-containers'
## Run a quick command in a pod (for troubleshooting)
#alias kexec='kubectl exec -it'
## Apply a manifest file
#alias kap='kubectl apply -f'
## Delete a resource from a manifest file
#alias kdel='kubectl delete -f'
## Get current context
#alias kc='kubectl config current-context'
## List all contexts
#alias kctx='kubectl config get-contexts'
## Switch context
#alias ksctx='kubectl config use-context'
## Get nodes with wide output
#alias knodes='kubectl get nodes -o wide'
## Get persistent volume claims (PVCs) in all namespaces
#alias kpvc='kubectl get pvc -A'
## Get services in the current namespace
#alias ksvc='kubectl get svc'
## Quickly apply all YAML files in a directory
#alias kapd='kubectl apply -f .'
## Restart all pods in a deployment (useful for refreshing)
#alias kres='kubectl rollout restart deployment'
## Get events in all namespaces (useful for troubleshooting)
#alias kevents='kubectl get events -A --sort-by=.metadata.creationTimestamp'
## View the resource usage (CPU/memory) of nodes
#alias ktopn='kubectl top nodes'
## View the resource usage (CPU/memory) of pods
#alias ktop='kubectl top pods'
## Tail logs of a specific container in a pod
#alias klc='kubectl logs -f -c'
## Get all pods not in "Running" state
#alias knr='kubectl get pods --field-selector=status.phase!=Running'
#
#
## Check if Kubernetes admin mode is enabled, if enabled run kgr as startup
#if [ "$KUBE_ADMIN" = "true" ]; then
#  kgr
#fi
#EOF






