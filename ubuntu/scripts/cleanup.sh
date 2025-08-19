#!/bin/bash -eux

# -- Shell Config --

# Redirect stderr to stdout for the entire script, this will get rid of most of the red in my terminal because in Packer,
# the output from the script section (provisioners) is shown in red because it's directed to stderr, which Packer highlights in red.
exec 2>&1


# --  Environment Variables  --

# set var to log path
LOG="/var/log/cleanup.log"
# set to default ubuntu user
USER_NAME="ubuntu"

# -- Main Script Section --

echo "==> remove SSH keys used for building"
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /root/.ssh/authorized_keys

echo "==> Clear out machine id"
truncate -s 0 /etc/machine-id

echo "==> Remove the contents of /tmp and /var/tmp"
rm -rf /tmp/* /var/tmp/*

echo "==> Truncate any logs that have built up during the install"
find /var/log -type f -exec truncate --size=0 {} \;

echo "==> Cleanup bash history"
rm -f ~/.bash_history

echo "remove /usr/share/doc/"
rm -rf /usr/share/doc/*

echo "==> remove /var/cache"
find /var/cache -type f -exec rm -rf {} \;

echo "==> Cleanup apt"
apt-get -y autoremove
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo "==> force a new random seed to be generated"
rm -f /var/lib/systemd/random-seed

echo "==> Clear the history so our install isn't there"
rm -f /root/.wget-hsts

# reconfigure password of default ubuntu install user
# Set the user password from Packer variable called on line 58 of the template
echo "Setting password for $USER_NAME..."
echo "${USER_NAME}:${USER_PASSWORD}" | sudo chpasswd

# Log that password has been set, but do not log the password itself
echo "Password for $USER_NAME set." >> $LOG

# Remove cloud init network configuration from netplan
sudo rm -rf /etc/netplan/50-cloud-init.yaml

export HISTSIZE=0