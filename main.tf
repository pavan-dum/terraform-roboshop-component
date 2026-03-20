resource "aws_instance" "main" {

  ami = local.ami_id
  instance_type = "t3.micro"
  subnet_id = local.private_subnet_id
  vpc_security_group_ids = [local.sg_id]
  

  tags = merge(
    {
        Name = "${var.project}-${var.Environment}-main"
    },
  
        local.common_tags
  )
   
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

connection {
    type ="ssh"
    user = "ec2-user"
    password = "DevOps321"
    host = aws_instance.main.private_ip
  }

provisioner "file" {
  source = "bootstrap.sh" # local file path
  destination = "/tmp/bootstrap.sh"   # destination path on the rempote machine
}

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.component} ${var.Environment}"]
  }
}


# resource stop 
resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on  = [terraform_data.main]
}

#capturing ami image from stopped instance 
resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.Environment}-${var.component}"
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]
}


# target group 
resource "aws_lb_target_group" "main" {
  name     = "${var.project}-${var.Environment}-${var.component}"
  port     = local.port_number
  protocol = local.protocol
  vpc_id   = local.vpc_id

  deregistration_delay = 60

  health_check {
    healthy_threshold = 2
    interval = 10 
    matcher = "200-299"
    path = local.health_check_path
    port = local.port_number
    protocol = local.protocol
    timeout = 2
    unhealthy_threshold = 3
  }
}


# launch template
resource "aws_launch_template" "main" {
  name = "${var.project}-${var.Environment}-${var.component}"

  image_id = aws_ami_from_instance.main.id
  
  #once auto scaling is less traffic it will terminate the instance
  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  vpc_security_group_ids = [local.sg_id]
  
  # each time we apply terraform this version will be updated as default
  update_default_version =  true
  
  #instance tags created by launch template through auto scaling
  tag_specifications {
    resource_type = "instance"

    tags = merge(
        {
          Name = "${var.project}-${var.Environment}-${var.component}"
        },
        local.common_tags
      )
  }

  # volume tags created by instances
  tag_specifications {
    resource_type = "volume"

    tags = merge(
        {
          Name = "${var.project}-${var.Environment}-${var.component}"
        },
        local.common_tags
      )
  }

  # launch template tags
  tags = merge(
        {
          Name = "${var.project}-${var.Environment}-${var.component}"
        },
        local.common_tags
      )
}


# auto scaling group
resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.Environment}-${var.component}"
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = false
  
  launch_template {
  id      = aws_launch_template.main.id
  version = "$Latest"
  }   
  vpc_zone_identifier       = [local.private_subnet_id]

  # we are adding ${var.component} to target group
  target_group_arns = [aws_lb_target_group.main.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  dynamic "tag" {

    for_each = merge(
        {
          Name = "${var.project}-${var.Environment}-${var.component}"
        },
        local.common_tags
      )
  
  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = false
  }

  }

  # with in 15 min auto scaling should be successful
  timeouts {
    delete = "15m"
  }
}

# auto scaling policy
resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "${var.project}-${var.Environment}-${var.component}"
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}
  
# listener rule this is depends on target group
resource "aws_lb_listener_rule" "main" {
  listener_arn = local.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.host_header]
    }
  }
}

# destroy instance

resource "terraform_data" "delete_instance" {

  triggers_replace = [
     aws_instance.main.id
  ]

  depends_on = [aws_autoscaling_policy.main]
  
  #it executes in bastion
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }

  
}


 