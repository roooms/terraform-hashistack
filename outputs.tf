# Outputs
output "asg_id" {
  value = "${aws_autoscaling_group.hashistack_server.id}"
}

output "consul_client_sg_id" {
  value = "${aws_security_group.consul_client.id}"
}

output "hashistack_server_sg_id" {
  value = "${aws_security_group.hashistack_server.id}"
}
