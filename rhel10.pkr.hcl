packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# Specify VM name.
variable "vm_name" {
  type    = string
  default = "rhel10vm"
}

# Specify hostname used by O.S.
variable "host_name" {
  type    = string
  default = "rhel10host"
}

# Specify filename of installation ISO.
variable "iso_url" {
  type    = string
  default = "./Rocky-10.2-x86_64-dvd1.iso"
}

# Specify SHA256 checksum of above ISO.
variable "iso_checksum256" {
  type    = string
  default = "16ca9c96cdb221ba6e1f68579f21bd69fd8da81c6a921d9068949796f91c8feb"
}

# Specify host-only network interface.
variable "hostonly_nic" {
  type    = string
  default = "enp0s8"
}

# Specify host-only static IP address (in CIDR format).
variable "hostonly_ip" {
  type    = string
  default = "192.168.56.15/24"
}

# Boolean variable for conditional set up for Ansible.
variable "setup_ansible" {
  type    = bool
  default = false
}

# Define Ansible user (used if setup_ansible = true)
variable "ansible_userid" {
  type    = string
  default = "ansible"
}

# Define Ansible user public key (used if setup_ansible = true)
variable "ansible_public_key" {
  type    = string
  default = <REPLACE>
}



source "virtualbox-iso" "rhel10" {
  vm_name              = var.vm_name
  guest_os_type        = "RedHat_64"

  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum256

  ssh_username         = "packer"
  ssh_password         = "packer"
  ssh_timeout          = "30m"

  shutdown_command     = "echo 'packer' | sudo -S shutdown -P now"

  disk_size            = 30720
  hard_drive_interface = "sata"

  cpus                 = 1
  memory               = 8192

  headless             = false

  guest_additions_mode = "attach"

  boot_wait            = "30s"

  boot_command = [
    "e",
    "<wait>",
    "<down><down>",
    "<end>",
    " inst.text",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<f10>"
  ]

  http_directory = "http"

  # Configure some preferred VM settings.
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic1", "nat"],
    ["modifyvm", "{{.Name}}", "--nic2", "hostonly", "--hostonlyadapter2", "VirtualBox Host-Only Ethernet Adapter"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{ .Name }}", "--vrde", "off"],
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
    ["modifyvm", "{{ .Name }}", "--clipboard", "bidirectional"],
    ["modifyvm", "{{ .Name }}", "--draganddrop", "bidirectional"]
  ]

  # Configuration to alter after VM created.
  vboxmanage_post = [
    # PLACE-HOLDER
  ]

}

build {
  sources = [
    "source.virtualbox-iso.rhel10"
  ]

# Reset host-only adapter to static IP
  provisioner "shell" {
    inline = [
      "sudo nmcli connection modify ${var.hostonly_nic} ipv4.method manual ipv4.addresses ${var.hostonly_ip}",
      "sudo nmcli connection down ${var.hostonly_nic}",
      "sudo nmcli connection up ${var.hostonly_nic}"
    ]
}

# Reset hostname defined in O.S.
  provisioner "shell" {
    inline = [
      "sudo hostnamectl set-hostname ${var.host_name}"
    ]
}

# Update system packages.
  provisioner "shell" {
    inline = [
      "sudo dnf -y update"
    ]
}

# OPTIONAL - Set up user with SSH key for Ansible.
  provisioner "shell" {
    inline = [
      "if [ '${var.setup_ansible}' = 'true' ]; then",
      "  sudo useradd -G wheel -m -s /bin/bash ${var.ansible_userid}",
      "  echo '${var.ansible_userid} ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/${var.ansible_userid} > /dev/null",
      "  sudo chmod 440 /etc/sudoers.d/${var.ansible_userid}",
      "  sudo mkdir -p /home/${var.ansible_userid}/.ssh",
      "  sudo chmod 700 /home/${var.ansible_userid}/.ssh",
      "  sudo touch /home/${var.ansible_userid}/.ssh/authorized_keys",
      "  sudo chmod 600 /home/${var.ansible_userid}/.ssh/authorized_keys",
      "  echo ${var.ansible_public_key} | sudo tee -a /home/${var.ansible_userid}/.ssh/authorized_keys",
      "  sudo chown -R ${var.ansible_userid}:${var.ansible_userid}   /home/${var.ansible_userid}/.ssh",
      "else",
      "  echo 'Skipping ansible user set up.'",
      "fi"
    ]
}

# Copy over a custom file at the end of the setup (an example file copy).
 provisioner "file" {
    source = "Computer_Notice.md"
    destination = "/tmp/Computer_Notice.md"
  }
}
