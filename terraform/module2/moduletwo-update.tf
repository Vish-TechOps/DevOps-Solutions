##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "key_name" {
  default = "vish_techops_key"
}

variable "network_address_space" {
  default = "10.10.0.0/16"
}

variable "subnet1_address_space" {
  default = "10.10.1.0/24"
}

variable "subnet2_address_space" {
  default = "10.10.2.0/24"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-west-1"
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_address_space}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "subnet1" {
  cidr_block              = "${var.subnet1_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
  cidr_block              = "${var.subnet2_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "httpd_elb_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Nginx security group 
resource "aws_security_group" "httpd-sg" {
  name   = "httpd_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  name = "httpd-elb"

  subnets         = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.httpd1.id}", "${aws_instance.httpd2.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# INSTANCES #
resource "aws_instance" "httpd1" {
  ami                    = "ami-824c4ee2"
  instance_type          = "t2.micro"
  subnet_id              = "${aws_subnet.subnet1.id}"
  vpc_security_group_ids = ["${aws_security_group.httpd-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo service httpd start",
    ]
  }
}

resource "aws_instance" "httpd2" {
  ami                    = "ami-824c4ee2"
  instance_type          = "t2.micro"
  subnet_id              = "${aws_subnet.subnet2.id}"
  vpc_security_group_ids = ["${aws_security_group.httpd-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo service httpd start",
    ]
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = "${aws_elb.web.dns_name}"
}

