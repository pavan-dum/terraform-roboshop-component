data "aws_ami" "rhel_id" {
  most_recent = true
  owners      = ["973714476881"]

  filter {
    name   = "name"
    values = ["Redhat-9-DevOps-Practice"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


data "aws_ssm_parameter" "private_subnet_ids" {
    name = "/${var.project}/${var.Environment}/private_subnet_ids"
}


data "aws_ssm_parameter" "sg_id" {
    name = "/${var.project}/${var.Environment}/${var.component}_sg_id"
}

data "aws_ssm_parameter" "vpc_id" {
    name = "/${var.project}/${var.Environment}/vpc_id"
}

data "aws_ssm_parameter" "backend_alb_listener_arn" {
    name = "/${var.project}/${var.Environment}/backend_alb_listener_arn"
}

data "aws_ssm_parameter" "frontend_alb_listener_arn" {
    name = "/${var.project}/${var.Environment}/frontend_alb_listener_arn"
}