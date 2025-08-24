variable "output_raw" {
  type        = bool
  default     = true
  description = "Set to true if you want the output in raw format."
}

variable "qemu_accelerator" {
  type        = string
  default     = "kvm"
  description = "Qemu accelerator to use. On Linux use kvm and macOS use hvf."
}

variable "ubuntu_version" {
  type        = string
  default     = "noble"
  description = "Ubuntu codename version (i.e. 20.04 is focal and 22.04 is jammy)"
}

variable "user_password" {
  description = "For initial deployment we use the default user & pass, when cleaning up the deployment we need to change this password to a new value"
  type        = string
  default     = "changeme"
}