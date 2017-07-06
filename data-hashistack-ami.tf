data "aws_ami" "hashistack" {
  most_recent = true
  owners      = ["362381645759"]

  filter {
    name   = "tag:System"
    values = ["HashiStack"]
  }

  filter {
    name   = "tag:Environment"
    values = ["${var.environment}"]
  }

  filter {
    name   = "tag:OS"
    values = ["${var.os}"]
  }

  filter {
    name   = "tag:OS-Version"
    values = ["${var.os_version}"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "tag:Consul-Version"
    values = ["${var.consul_version}"]
  }

  filter {
    name   = "tag:Nomad-Version"
    values = ["${var.nomad_version}"]
  }

  filter {
    name   = "tag:Vault-Version"
    values = ["${var.vault_version}"]
  }
}
