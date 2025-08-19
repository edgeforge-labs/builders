# Packer - Ubuntu Cloud Image (WIP)

# ☁️ Cloud-Init Configuration

Our Cloud-Init configuration automates the initial setup of an Ubuntu instance, including **hostname configuration, system locale, timezone, and software installation**.

## 📦 Software Installation
These packages are automatically installed on first boot:

- `qemu-guest-agent` – Improves VM integration  
- `git` – Version control  
- `net-tools` – Networking tools
- `nfs-common` – NFS support
- `curl` – HTTP request tool  
- `file` – File type detection  
- `build-essential` – Compiler tools  
- `zsh` – Alternative shell  
- `neofetch` – System info display  
- `bpytop` – System monitoring  

## 🛠️ Configuration Overview
### Hostname Setup
- **Cloud-Init defines variables** (`ROLE`, `ENV`, `COUNTER`) in `/etc/profile.d/hostname_vars.sh`.  
- The **post-Cloud-Init script** reads these variables and configures the **hostname dynamically** using:  
  ```bash
  "${ROLE}-${ARCH}-${ENV}-${COUNTER}"
  ```

### 🚧 User & SSH Authentication
 **TODO: Improve SSH Key Handling**

- Currently, Cloud-Init **enables password authentication** (`ssh_pwauth: true`).  
- **Password: `ubuntu`** is set but later removed by the script.  
- **Better approach:** Set up SSH keys **immediately** in Cloud-Init.  

### **System Localization**
- **Locale:** `nl_BE.UTF-8`  
- **Keyboard Layout:** `be` (Belgian)  
- **Timezone:** `Europe/Brussels`

## 🚀 Future Improvements
- [ ] **Replace password auth with SSH key authentication** in Cloud-Init.  This can break packer so carefully implement
- [ ] **Enable Fail2Ban** security rules in Cloud-Init.  
- [ ] **Refactor hostname governance** logic to ensure proper dynamic assignment.

# 📜 Script Architecture

**TODO: Move all the functionality to PDS and just import here, script should be select and apply**

The script automates post-cloud-init configuration for a Linux instance, ensuring proper system setup, user creation, shell customization, and security hardening.

## 🔧 Configuration Overview
### 1️⃣ System Configuration
- **User Management**  
  - Creates an admin user (`sysadmin`).  
  - Sets up SSH key-based authentication.  
  - Enables passwordless sudo for the admin.  
  - ⚠️ *Cloud-Init user provisioning can break SSH access—investigate or handle via script.*  

- **Hostname Setup**  
  - Generates hostname dynamically based on system variables.  
  - Applies the new hostname to `/etc/hosts`.  

- **SSHD Configuration**  
  - Disables root login.  
  - Enables only key-based authentication.  
  - Password authentication is disabled by default.  

- **Zsh Configuration**  
  - Installs and sets up **Zi** (Zsh package manager).  
  - Configures **Powerlevel10k**, **autosuggestions**, and **syntax highlighting**.  
  - Applies system-wide Zsh configuration to `/etc/zshrc`.  

- **Custom MOTD (Message of the Day)**  
  - Configures **Neofetch** as the system MOTD.  
  - Backs up existing MOTD scripts.  

## 🛡️ Security Hardening
- **Disables password authentication and root login**  
- **Configures Fail2Ban (TBD)**
- **Enables Uncomplicated Firewall (UFW) (TBD)**
- **Automated Updates via Cron**  
  - Ensures a **nightly update at midnight**.  
  - Uses `grep` to prevent duplicate cron entries.  

## 📦 Tooling & Extras
### **🐳 Kubernetes CLI (kubectl)**
- Installs `kubectl` and additional utilities (`stern`, `kubectl-view-secret`).  
- Adds **alias `k=kubectl`** and enables shell completion.  

## 🔗 References
- **[Packer Documentation](https://www.packer.io/docs)** - Official Packer
- **[Cloud-Init Documentation](https://cloudinit.readthedocs.io/en/latest/)** - Official Cloud-Init
- **[Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)** - Official Ubuntu Cloud Images
- **[Original Template Repository](https://github.com/nbarnum/packer-ubuntu-cloud-image/tree/main)** - Shout out to the original author for the base template, @nbarnum, I used it as a starting point for this project.

## Debugging

Set the environment variable `PACKER_LOG=1` to provide additional debug logging

forward vnc

```shell
ssh -N -L 5905:127.0.0.1:5905 sysadmin@x86
```

