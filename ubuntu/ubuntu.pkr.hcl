packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

source "qemu" "ubuntu" {
  accelerator      = var.qemu_accelerator
  cd_files         = ["./cloud-init/*"]
  cd_label         = "cidata"
  disk_compression = true
  disk_image       = true
  disk_size        = "10G"
  headless         = true
  iso_checksum     = "file:https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/SHA256SUMS"
  iso_url          = "https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/${var.ubuntu_version}-server-cloudimg-amd64.img"
  output_directory = "output-${var.ubuntu_version}"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  ssh_password     = "ubuntu"
  ssh_username     = "ubuntu"
  vm_name          = "ubuntu-${var.ubuntu_version}.img"
  qemuargs = [
    ["-m", "2048M"],
    ["-smp", "2"],
    ["-serial", "mon:stdio"],
  ]
}

build {
  sources = ["source.qemu.ubuntu"]

  # try manual install first
  provisioner "file" {
    source      = "scripts/.p10k.zsh"       # Local path relative to Packer host
    destination = "/tmp/.p10k.zsh"
  }

  provisioner "file" {
    source      = "scripts/zshrc"
    destination = "/tmp/zshrc"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/.p10k.zsh /etc/.p10k.zsh",
      "sudo mv /tmp/zshrc /etc/zshrc",
      "sudo chmod 644 /etc/.p10k.zsh",
      "sudo chmod 644 /etc/zshrc"
    ]
  }

  provisioner "shell" {
    // run scripts with sudo, as the default cloud image user is unprivileged
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    // NOTE: cleanup.sh should always be run last, as this performs post-install cleanup tasks
    scripts = [
      "scripts/install.sh",
      "scripts/cleanup.sh"
    ]

    environment_vars = [
      "USER_PASSWORD=${var.user_password}"
    ]
  }

  post-processor "shell-local" {
    inline = [
      # Convert QCOW2 to RAW if enabled
      "if [ \"${var.output_raw}\" = true ]; then qemu-img convert -f qcow2 -O raw output-${var.ubuntu_version}/ubuntu-${var.ubuntu_version}.img output-${var.ubuntu_version}/ubuntu-${var.ubuntu_version}.raw; fi",

      # Compress the raw image using xz
      # "if [ \"${var.output_raw}\" = true ]; then xz -9 output-${var.ubuntu_version}/ubuntu-${var.ubuntu_version}.raw -v; fi",
    ]
  }
}
