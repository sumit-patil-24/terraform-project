provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "public_sub1" {
  vpc_id= aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone  = "us-east-1a"
  map_public_ip_on_launch = true    
}

resource "aws_subnet" "public_sub2" {
  vpc_id= aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone  = "us-east-1b"
  map_public_ip_on_launch = true    
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.public_sub1.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.public_sub2.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_route_table" "RT1" {
  vpc_id = aws_vpc.my_vpc.id
  route{
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table" "RT2" {
  vpc_id = aws_vpc.my_vpc.id
  route{
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "rta11" {
    subnet_id = aws_subnet.private_subnet1.id
    route_table_id = aws_route_table.RT1.id
}
resource "aws_route_table_association" "rta22" {
    subnet_id = aws_subnet.private_subnet2.id
    route_table_id = aws_route_table.RT2.id
}

resource "aws_security_group" "mysg" {
  name = "webig"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "HTTP from vpc"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Web.sg"
  }

  
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_sub1.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_instance" "webserver1" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id = aws_subnet.private_subnet1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id = aws_subnet.private_subnet2.id
  user_data = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "mylb" {
    name = "myalb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.mysg.id]
    subnets = [aws_subnet.public_sub1.id, aws_subnet.public_sub2.id]
}

resource "aws_lb_target_group" "tg" {
  name = "myTG"
  port =80
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  } 
    
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.mylb.dns_name
}


