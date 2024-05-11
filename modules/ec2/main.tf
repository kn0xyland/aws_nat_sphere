# Launch Configuration

resource "aws_launch_configuration" "lc" {
  name_prefix                      = "${var.name_prefix}_lc-"
  image_id                         = var.image_id
  instance_type                    = var.instance_type
  iam_instance_profile             = aws_iam_instance_profile.sphere_profile.arn
  key_name                         = var.key_name
  security_groups                  = [var.security_group_id]
  associate_public_ip_address      = var.associate_public_ip_address
  user_data = base64encode(templatefile("scripts/user_data.sh", { 
    AWSREGION = var.awsregion, 
    ZONEID = var.zoneid, 
    CIDR = var.cidr, 
    NAME_PREFIX = var.name_prefix, 
    VPC_IDENT = var.vpc_ident,
    TIMEZONE = var.timezone,
    FQDN = var.fqdn,
    WG0CIDR = var.wg0cidr
  }))
  enable_monitoring                = var.enable_monitoring
  ebs_optimized                    = var.ebs_optimized
  dynamic "root_block_device" {
    for_each = var.root_block_device
    content {
      delete_on_termination = true
      iops                  = "3000"
      volume_size           = "10"
      volume_type           = "gp3"
    }
  }
  dynamic "ebs_block_device" {
    for_each = var.ebs_block_device
    content {
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", null)
      device_name           = ebs_block_device.value.device_name
      encrypted             = lookup(ebs_block_device.value, "encrypted", null)
      iops                  = lookup(ebs_block_device.value, "iops", null)
      no_device             = lookup(ebs_block_device.value, "no_device", null)
      snapshot_id           = lookup(ebs_block_device.value, "snapshot_id", null)
      volume_size           = lookup(ebs_block_device.value, "volume_size", null)
      volume_type           = lookup(ebs_block_device.value, "volume_type", null)
    }
  }

  placement_tenancy = var.placement_tenancy

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = ["${var.name_prefix}-vpc"]
  }
}

resource "aws_autoscaling_group" "asg" {
  count                     = "${var.deploy_sphere}"
  name                      = "${var.name_prefix}_asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  launch_configuration      = aws_launch_configuration.lc.name
  desired_capacity          = var.desired_capacity
  metrics_granularity       = var.metrics_granularity
  enabled_metrics           = var.enabled_metrics
  service_linked_role_arn   = var.service_linked_role_arn  # todo: needed?
  vpc_zone_identifier       = [var.vpc_ident]

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-${var.awsregion}"
    propagate_at_launch = true
  }
}

resource "aws_iam_role" "sphere_role" {
  name = "${var.name_prefix}_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      name = "ec2 assume role"
  }
}

resource "aws_iam_instance_profile" "sphere_profile" {
  name = "${var.name_prefix}_profile"
  role = "${aws_iam_role.sphere_role.name}"
  depends_on = [aws_iam_role.sphere_role]
}

resource "aws_iam_role_policy" "sphere_policy" {
  name = "${var.name_prefix}_policy"
  role = "${aws_iam_role.sphere_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:ModifyInstanceAttribute",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:DescribeRouteTables",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets"
      ],
      "Effect": "Allow",
      "Resource": [
      "arn:aws:route53:::hostedzone/${var.zoneid}"
       ]
    },
    {
      "Sid": "AllowParameterAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:${var.awsregion}:${var.aws_account_id}:parameter/${var.name_prefix}/*"
      ]
    },
    {
      "Sid": "AllowSGUpdates",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": [
        "arn:aws:ec2:${var.awsregion}:${var.aws_account_id}:security-group/${var.security_group_id}"
      ]
    }
  ]
}
EOF
  depends_on = [aws_iam_role.sphere_role]
}

data "aws_iam_policy_document" "sphere_policy" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.zoneid}",
    ]
  }
}