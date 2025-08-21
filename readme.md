# Packer 

This repository provides Packer templates and scripts for building linux images, specifically tailored for use with cloud-init and automation tools. 
The goal is to create a streamlined process for generating ready-to-use images that can be deployed in various environments.
This is great for organisations that need to maintain consistent and secure base images across their infrastructure ([golden image concept](https://www.redhat.com/en/topics/linux/what-is-a-golden-image)).

## Installation

Packer can be installed on both x86 and ARM64 architectures. The recommended installation method uses Hashicorp's official package repositories with dynamic architecture detection.

```bash
# Install required packages
sudo apt install -y wget curl gnupg software-properties-common
# Add HashiCorp GPG key and repository
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Packer and required QEMU packages
sudo apt update
sudo apt install -y packer

# Install architecture-specific dependencies
if [ "$(dpkg --print-architecture)" = "amd64" ]; then
    # x86 (amd64) specific packages
    sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
else
    # ARM64 specific packages
    sudo apt install -y qemu-system-arm qemu-system-aarch64 qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
fi

# Install QEMU plugin for Packer
sudo packer plugins install github.com/hashicorp/qemu
```

> [!NOTE]
> The installation scripts auto-detect your system architecture and install the appropriate packages. For non-Debian based distributions, adjust the package installation commands accordingly.

## Creating Images with Packer

### Packer Template Structure

Our Packer templates define how to build custom images. Key components include:

- **Source Configuration**: Specifies the base image, VM settings, and QEMU parameters
- **Build Configuration**: Defines provisioners for customization and post-processors for output format
- **Variable Definitions**: Parameters that can be customized per build

### Cloud-init Configuration

The Cloud-init configuration is packed into the image as a virtual CD-ROM (ISO):y

- The `cd_files` directive specifies the path to the `user-data` and `meta-data` files.
- The `cd_label` is set to `cidata`, which Cloud-Init expects for NoCloud configuration.
- When the VM boots, Cloud-Init reads these files to configure the instance.

### Extra Provisioning Scripts

In addition to Cloud-init, we use shell scripts to perform additional customization:

- Install packages
- Configure system settings
- Set up custom motd messages
- Any other specialized configuration needed

## Build Instructions

To build the image:

```bash
cd build/packer/ubuntu-cloud-image/
sudo packer init
sudo packer build -var-file=variables.pkrvars.hcl .
# Tip: Add this alias to your shell config
# alias pb='sudo packer build -var-file=variables.pkrvars.hcl .'
```

After running the Packer build, you'll find the final raw image in the `output-ubuntu-image` directory.

## Testing & Troubleshooting

### Troubleshoot image during creation

#### Connect to image via VNC during build

If you're on a Linux system with graphical capabilities:

1. **Install TigerVNC Viewer**:
   ```bash
   sudo apt-get install tigervnc-viewer   # Ubuntu/Debian
   sudo dnf install tigervnc              # Fedora
   ```

2. **Connect to the VNC server**:
   ```bash
   vncviewer 127.0.0.1:5956
   ```

#### SSH Tunnel for Remote Shell Use

For headless environments, tunnel VNC through SSH:

1. **Create an SSH tunnel**:
   ```bash
   ssh -N -L 5956:127.0.0.1:5956 remote_user@remote_host
   ```

2. **Connect via VNC locally**:
   ```bash
   vncviewer 127.0.0.1:5956
   ```

3. **For Windows users**: Use MobaXterm as VNC viewer.

### Troubleshoot image after creation

#### Use QEMU to Boot x86 Images

To boot and access the shell of an x86 image:

```bash
sudo qemu-system-x86_64 \
-drive file=/path/to/output-noble/ubuntu-noble.img,format=qcow2 \
-smp cores=4,sockets=1 \
-m 4G \
-net nic -net user,hostfwd=tcp::2222-:22 \
-nographic
```

#### Use QEMU to Boot ARM64 Images

To boot an ARM64 image with QEMU:

```bash
sudo qemu-system-aarch64 -m 2048 -cpu cortex-a72 \
  -M virt \
  -drive file=/path/to/armbian-image.img,format=raw \
  -serial mon:stdio \
  -netdev user,id=user.0 \
  -device virtio-net,netdev=user.0,romfile=
```

#### Shell Access via chroot

To inspect the image filesystem without booting:

1. **Create a mount directory**:
   ```bash
   sudo mkdir /mnt/image
   ```

2. **Mount the image**:
   ```bash
   sudo mount -o loop /path/to/your/image.raw /mnt/image
   ```

   For images with multiple partitions:
   ```bash
   sudo fdisk -l /path/to/your/image.img  # Find partition offset
   # Calculate offset: start_sector * 512
   sudo mount -o loop,offset=<calculated_offset> /path/to/your/image.img /mnt/image
   ```

3. **Enter chroot environment**:
   ```bash
   sudo chroot /mnt/image /bin/bash
   ```

4. **Exit and unmount**:
   ```bash
   exit
   sudo umount /mnt/image
   ```
<!--
## Advanced Topics

### Automating Future Builds

Once you have your Packer templates configured, you can automate builds through CI/CD pipelines:

- Use GitHub Actions or Equivalent to trigger builds when configurations change
- Schedule regular builds to incorporate security updates
- Implement testing frameworks to validate image functionality

### Working with Armbian U-Boot

For advanced ARM64 booting scenarios, you might need to work with U-Boot:

1. **Extract U-Boot from image**:
   ```bash
   # Mount image with correct offset
   sudo mount -o loop,offset=16777216 /path/to/armbian-image.img /mnt/armbian
   # Copy U-Boot binary
   sudo cp /mnt/armbian/boot/u-boot.bin ./
   ```

2. **Boot with U-Boot in QEMU**:
   ```bash
   qemu-system-aarch64 \
       -machine virt -cpu cortex-a72 -m 2048 \
       -serial stdio \
       -bios ./u-boot.bin \
       -drive if=none,file=/path/to/armbian-image.qcow2,id=mydisk \
       -device ich9-ahci,id=ahci \
       -device ide-hd,drive=mydisk,bus=ahci.0
   ```
-->
## References

- [Customize MOTD](https://www.putorius.net/custom-motd-login-screen-linux.html)
- [Original Repo Reference For Packer Config](https://github.com/nbarnum/packer-ubuntu-cloud-image/tree/main)
- [Packer Builder ARM](https://github.com/mkaczanowski/packer-builder-arm)
- [Official Qemu Docs](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu)
- [Armbian QEMU Boot Guide](https://forum.armbian.com/topic/38258-running-self-build-image-on-qemu-arm64/)
- [ARM64 QEMU Examples](https://gist.github.com/wuhanstudio/e9b37b07312a52ceb5973aacf580c453)
