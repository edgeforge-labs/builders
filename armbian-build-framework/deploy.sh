#!/bin/bash

# This script will bootstrap a build host to create an image
ENV=$(pwd)
# setup required dependencies
sudo apt install git curl zip unzip rsync bc -y

# clone framework
# Check if the directory exists
if [ ! -d "$ENV/build" ]; then
  echo "Directory $ENV/build does not exist. Cloning repository..."
  git clone https://github.com/armbian/build
else
  echo "Directory $ENV/build already exists. Skipping clone."
fi


# Function to handle the copy process and directory creation
#copy_cloud_init_files() {
#  echo "Creating and copying files to $ENV/build/userpatches/extensions/cloud-init"
#  mkdir -p "$ENV/build/userpatches/extensions"
#  echo "EXTENSIONS=\"\$EXTENSIONS cloud-init\"" > "$ENV/build/userpatches/config.lib"
#  cp -r "$ENV/cloud-init" "$ENV/build/userpatches/extensions/"
#  ls -al "$ENV/build/userpatches/extensions/cloud-init"
#
#  echo "Configuration that will be applied:"
#  cat "$ENV/cloud-init/defaults/meta-data"
#  cat "$ENV/cloud-init/defaults/user-data"
#}

# TODO: we should modify this function so that it copies the cloud-init.sh from source and only our changes to defaults are added to it.
# TODO: Split up function into smaller sub functions for modularity: Copy extension / Set lib config / customization script per board type
# This is to make sure if anything changes that we won't be using an outdated script in our pipeline.
copy_init_files() {
  echo "[INFO] - Creating userpatches/extensions directory"
  mkdir -p "$ENV/build/userpatches/extensions"

  echo "[INFO] - Copying files to $ENV/build/userpatches/extensions/cloud-init"
  cp -r "$ENV/cloud-init" "$ENV/build/userpatches/extensions/"      #TODO: this needs to be changed to the files from the repo unless we specifically modify them. to stay in line with any updates to the code.
  ls -al "$ENV/build/userpatches/extensions/cloud-init"

  echo "[INFO] - Enable extension in lib.config"
  echo "ENABLE_EXTENSIONS=\"cloud-init\"" > "$ENV/build/userpatches/lib.config"

  echo "[INFO] - Copying Customization Script to userpatches"
  cp -f "$ENV/custom/customize-image.sh" "$ENV/build/userpatches/customize-image.sh"

# TODO: Improve output to terminal by either modifying the scripts or fetching vars from it
  echo "[INFO] - Configuration that will be applied:"
  echo "[INFO] - meta-data config"
  cat "$ENV/cloud-init/defaults/meta-data"
  echo "[INFO] - user-data config"
  cat "$ENV/cloud-init/defaults/user-data"
  echo "[INFO] - customize-image config"
  cat "$ENV/build/userpatches/customize-image.sh"
}

# Check if a previous config is already applied, if not create the parent dirs and copy
if [ ! -d "$ENV/build/userpatches/extensions/cloud-init" ]; then
  echo "Directory $ENV/build/userpatches/extensions/cloud-init does not exist."
  copy_init_files
else
  echo "Directory $ENV/build/userpatches/extensions/cloud-init already exists."
  # Ask user if they want to remove the directory and re-copy the files
  read -rp "Do you want to remove the existing directory and copy new files? (y/n): " choice
  if [ "$choice" = "y" ]; then
    echo "Removing directory..."
    rm -rf "$ENV/build/userpatches/extensions/cloud-init"
    copy_init_files
  else
    echo "Skipping the copy."
  fi
fi



# next run the compile command with the required env vars, I'll provide the ones for noble rock5a
# TODO: Create bash function that allows to specific which version you want to pack.
#."$ENV/build/compile.sh" \
#BOARD=rock-5a \
#BRANCH=vendor \
#RELEASE=noble \
#BUILD_MINIMAL=no \
#BUILD_DESKTOP=no \
#KERNEL_CONFIGURE=no