#######################################
# VARIABLES
#######################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_pair_name" {
  default = "vish_techx_key"
}

######################################
# PROVIDERS
######################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "us-east-1"
}

#####################################
# RESOURCES
#####################################

resource "aws_instance" "nginx" {
  ami = "ami-0e2ff28bfb72a4e45"
  instance_type = "t2.micro"
  key_name = "${var.key_pair_name}"
  connection {
    user = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum update -y",
      "sleep 30",
      "sudo yum install httpd -y",
      "sudo service httpd start"
    ]
  }
}

#####################################
# OUTPUT
#####################################

output "aws_instance_public_dns" {
  value = "${aws_instance.nginx.public_dns}"
}
