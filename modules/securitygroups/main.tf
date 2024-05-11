resource "aws_security_group_rule" "allow-ssh-ingress" {
  type              = "ingress"
  description       = "Allow SSH"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       =  ["${var.myip}"]
  security_group_id = "${var.security_group_id}"

}

resource "aws_security_group_rule" "allow-wireguard-ingress" {
  type              = "ingress"
  description       = "Allow WireGuard"
  from_port         = 51820
  to_port           = 51820
  protocol          = "udp"
  cidr_blocks       =  ["${var.myip}"]
  security_group_id = "${var.security_group_id}"

}

resource "aws_security_group_rule" "allow-eastwest-tcp-ingress-private" {
  type              = "ingress"
  description       = "Allow ALL TCP on Private Subnets"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       =  ["${element(var.private_subnets, 0)}", "${element(var.private_subnets, 1)}", "${element(var.private_subnets, 2)}" ]
  security_group_id = "${var.security_group_id}"

}

resource "aws_security_group_rule" "allow-eastwest-udp-ingress-private" {
  type              = "ingress"
  description       = "Allow ALL UDP on Private Subnets"
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  cidr_blocks       =  ["${element(var.private_subnets, 0)}", "${element(var.private_subnets, 1)}", "${element(var.private_subnets, 2)}" ]
  security_group_id = "${var.security_group_id}"

}