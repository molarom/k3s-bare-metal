# Proxmox connection variables.
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

# VM specific variables
variable "config_file" {
    type = string 
    default = "rocky8-kickstart.cfg"
}

variable "sudo-password" {
    type = string
    sensitive = true
    default = "changeme"
}

source "proxmox-iso" "rocky-k3s-server" {
    
    # Proxmox connection settings
    proxmox_url     = "${var.proxmox_api_url}"
    username        = "${var.proxmox_api_token_id}"
    token           = "${var.proxmox_api_token_secret}"

    # Set true if using self-signed certificates.
    insecure_skip_tls_verify = true

    # VM General Settings
    node                 = "proxmox-srv"
    vm_id                = "100"
    vm_name              = "rocky-k3s-server"
    template_description = "Rocky Linux K3s Server Image"

    # VM ISO Settings
    iso_url             = "https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.7-x86_64-minimal.iso"
    iso_checksum        = "13c3e7fca1fd32df61695584baafc14fa28d62816d0813116d23744f5394624b"
    iso_storage_pool    = "local"
    unmount_iso         = "true"
    iso_download_pve    = "true"

    # Boot Commands
    boot_command = ["<up><tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.config_file}<enter><wait><enter>"]

    # VM Hardware Settings
    cores   = "1"
    memory  = "2048"
    
    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"
    
    disks {
        disk_size         = "20G"
        format            = "raw"
        storage_pool      = "local-lvm"
        type              = "virtio"
    }

    # VM Network Settings
    network_adapters {
        model    = "virtio"
        bridge   = "vmbr0"
        firewall = "false"
    }

    # Autoinstall Settings
    http_directory = "http"

    # SSH Settings
    ssh_username  = "rockadm"
    ssh_password  = "${var.sudo-password}"
    ssh_timeout   = "20m"
}

build {
    name = "rocky-k3s-srv"
    sources = ["source.proxmox-iso.rocky-k3s-server"]

    provisioner "shell" {
        execute_command = "echo ${var.sudo-password} | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
        inline          = [
                           "yum -y install epel-release", 
                           "yum repolist", 
                           "yum -y install ansible",
                           "pip3 install --system kubernetes"
                          ]
    }
    
    provisioner "ansible-local" {
        playbook_dir  = "ansible"
        playbook_file = "ansible/k3s.yml"
        galaxy_file = "ansible/requirements.yml"
        extra_arguments = [
                        "--extra-vars",
                        "\"ansible_sudo_pass=${var.sudo-password}\""
                        ]
    }
}
