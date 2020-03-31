data "aws_availability_zones" "all" {

}

resource "aws_security_group" "instance_sg"{
    name = "${var.cluster_name}-instance_sg"


    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_launch_configuration" "example_launch_configuration"{
    image_id = "ami-0c55b159cdfafe1f0"
    instance_type = var.instance_type
    security_groups = [aws_security_group.instance_sg.id]
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_autoscaling_group" "example_asg"{
    launch_configuration = aws_launch_configuration.example_launch_configuration.id
    availability_zones = data.aws_availability_zones.all.names
    load_balancers = [aws_elb.example_elb.name]
    health_check_type = "ELB"
    min_size = var.min_size
    max_size = var.max_size

    tag {
        key = "Name"
        value = "${var.cluster_name}-example_asg"
        propagate_at_launch = true
    }

}


resource "aws_security_group" "elb_sg" {

    name = "${var.cluster_name}-elb_sg"

    #Allow all outbound
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Inbound HTTP from anywhere
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_elb" "example_elb" {
    name = "${var.cluster_name}-example_elb"
    availability_zones = data.aws_availability_zones.all.names
    security_groups = [aws_security_group.elb_sg.id]
    # This adds a listener for incoming HTTP requests.

    health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = var.server_port
        instance_protocol = "http"
    }
}




