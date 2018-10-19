resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
  tags = { Name = "main" }
}

resource "aws_subnet" "public" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "192.168.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "private" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "192.168.2.0/24"
    availability_zone = "us-east-1b"
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "main"
  }
}

resource "aws_nat_gateway" "ngw" {
  subnet_id = "${aws_subnet.public.id}"
  allocation_id = "${aws_eip.lb.id}"
  tags {
    Name = "main"
  }
}

resource "aws_eip" "lb" {
  vpc = true 
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "internetgateway" {
  route_table_id = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.gw.id}"
  timeouts {
    create = "5m"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "natgateway" {
  route_table_id = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  timeouts {
    create = "5m"
  }
}

resource "aws_network_acl" "main" {
  vpc_id = "${aws_vpc.main.id}"
  subnet_ids = ["${aws_subnet.private.id}", "${aws_subnet.public.id}"],
  egress = {
    protocol = "-1"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  },
  ingress = {
    protocol = "-1"
    rule_no = 101
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }
}

resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "alb" {
  name        = "demogroup"
  description = "Allow inbound from marthees laptop alone"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["73.61.85.115/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "ec2instance" {
  name        = "allow_all"
  description = "Allow inbound from marthees laptop and ELB"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["73.61.85.115/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ec2instance1" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id     = "${aws_security_group.alb.id}"

  security_group_id = "${aws_security_group.ec2instance.id}"
}

resource "aws_security_group_rule" "ec2instance2" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  cidr_blocks = ["73.61.85.115/32"]

  security_group_id = "${aws_security_group.ec2instance.id}"
}

resource "aws_security_group_rule" "ec2instance3" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  cidr_blocks = ["73.61.85.115/32", "52.201.49.39/32"]

  security_group_id = "${aws_security_group.ec2instance.id}"
}


resource "aws_lb_target_group" "test" {
  name     = "martheesdemo-targetgroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb" "test" {
  name               = "martheesdemo-test"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${aws_subnet.public.id}", "${aws_subnet.private.id}"]

  enable_deletion_protection = true

  tags {
    Environment = "production"
  }
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.test.arn}"
  port              = "80"
  protocol          = "HTTP"
  

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.test.arn}"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0edb11b46a8d905f3"
  instance_type = "t2.small"
  key_name = "terraform"
  vpc_security_group_ids = ["${aws_security_group.ec2instance.id}"]
  subnet_id = "${aws_subnet.public.id}"
  

  tags {
    Name = "HelloWorld"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.web.id}"
  allocation_id = "eipalloc-0e413b338bff6a640"
}
