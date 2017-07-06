provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_version = ">= 0.9.3"
}

resource "aws_iam_role" "hashistack_server" {
  name               = "${var.cluster_name}-HashiStack-Server"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "hashistack_server" {
  name   = "SelfAssembly"
  role   = "${aws_iam_role.hashistack_server.id}"
  policy = "${data.aws_iam_policy_document.hashistack_server.json}"
}

resource "aws_iam_instance_profile" "hashistack_server" {
  name = "${var.cluster_name}-HashiStack-Server"
  role = "${aws_iam_role.hashistack_server.name}"
}

data "template_file" "init" {
  template = "${file("${path.module}/init-cluster.tpl")}"

  vars = {
    cluster_size     = "${var.cluster_size}"
    environment_name = "${var.environment_name}"
  }
}

resource "aws_launch_configuration" "hashistack_server" {
  image_id      = "${data.aws_ami.hashistack.id}"
  instance_type = "${var.instance_type}"
  user_data     = "${data.template_file.init.rendered}"
  key_name      = "${var.ssh_key_name}"

  security_groups = [
    "${aws_security_group.hashistack_server.id}",
    "${aws_security_group.consul_client.id}",
  ]

  associate_public_ip_address = false
  ebs_optimized               = false
  iam_instance_profile        = "${aws_iam_instance_profile.hashistack_server.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "hashistack_server" {
  launch_configuration = "${aws_launch_configuration.hashistack_server.id}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  name                 = "${var.cluster_name} HashiStack Servers"
  max_size             = "${var.cluster_size}"
  min_size             = "${var.cluster_size}"
  desired_capacity     = "${var.cluster_size}"
  default_cooldown     = 30
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "${format("%s HashiStack Server", var.cluster_name)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster-Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment-Name"
    value               = "${var.environment_name}"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "hashistack_server" {
  name        = "hashistack-server-sg"
  description = "Security Group for HashiStack Server Instances"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name    = "HashiStack Server (${var.cluster_name})"
    Cluster = "${replace(var.cluster_name, " ", "")}"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Vault Client Traffic
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Vault Cluster Traffic
  ingress {
    from_port = 8201
    to_port   = 8201
    protocol  = "tcp"
    self      = true
  }

  # DNS (TCP)
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS (UDP)
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP Consul
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Serf (TCP)
  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Serf (UDP)
  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Consul Server RPC
  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RPC Consul
  ingress {
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # UDP All outbound traffic
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All Traffic - Egress
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul_client" {
  name        = "consul-client-sg"
  description = "Security Group for Consul Client Instances"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name          = "Consul Client (${var.cluster_name})"
    ConsulCluster = "${replace(var.cluster_name, " ", "")}"
  }

  # Serf (TCP)
  ingress {
    from_port = 8301
    to_port   = 8302
    protocol  = "tcp"
    self      = true
  }

  # Serf (UDP)
  ingress {
    from_port = 8301
    to_port   = 8302
    protocol  = "udp"
    self      = true
  }

  # Server RPC
  ingress {
    from_port = 8300
    to_port   = 8300
    protocol  = "tcp"
    self      = true
  }

  # RPC
  ingress {
    from_port = 8400
    to_port   = 8400
    protocol  = "tcp"
    self      = true
  }

  # Nomad RPC
  ingress {
    from_port = 4647
    to_port   = 4647
    protocol  = "tcp"
    self      = true
  }

  # Nomad Serf
  ingress {
    from_port = 4648
    to_port   = 4648
    protocol  = "tcp"
    self      = true
  }

  # TCP All outbound traffic
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # UDP All outbound traffic
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    self      = true
  }
}
