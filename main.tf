# Thirteen things Terraform needs to get your Instance to work
# 1: Terraform Provider
# 2: VPC
# 3: Internet Gateway
# 4: Subnet
# 5: Global Route Table
# 6: Default Route to the Internet
# 7: Route Association between the subnet and the route table
# 5: Security Group to allow inbound ssh access
# 6: Public SSH Key
# 7: AMI (Operating System Image)
# 8: Instance Compute Size
# 9: Instance Hard Drive Size
#10: Public IP Address 
#11: Some Output ie IP Address, etc
#12: Tag your creations.
#13: Create a file (dev-example-key.pub) in the terraform code folder with the public ssh key in it.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.62.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" // Change to your desired region
}
####################
## Create the VPC ##
####################
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev-vpc"
  }
}
#################################
## Create the Internet Gateway ##
#################################
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}
#######################
## Create the Subnet ##
#######################
resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "dev-subnet"
  }
}
############################
## Create the Route Table ##
############################
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-route-table"
  }
}
##############################
## Create the Default Route ##
##############################
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.example.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id
}
##################################
## Create the Route Association ##
##################################
resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.example.id
  route_table_id = aws_route_table.example.id
}
#############################################
## Create the Security Group to allow SSH  ##
## Modify the cider_blocks to your home IP ##
#############################################
resource "aws_security_group" "example" {
  name_prefix = "dev-ssh-access"
  
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["66.0.0.97/32"] # Change this to your home ip
  }
    ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["66.0.0.97/32"] # Change this to your home ip
  }
    ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["66.0.0.97/32"] # Change this to your home ip
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] ## Allow all outbound traffic
  }
  tags = {
    Name = "dev-security-group"
  }
  
  vpc_id = aws_vpc.example.id
}
###########################################################################
## Does a search for the newest version of Amazon OS 2023                ##
## cli command: aws ec2 describe-images --image-id ami-06e46074ae430fba6 ##
###########################################################################
data "aws_ami" "latest_amazon_linux_2" {
  most_recent = true
  owners      = ["137112412989"]
    filter {
      name = "name"
      values = ["al2023-ami-2023.*x86_64"]
    }
}
############################################
## Dumps the AMI info out into a variable ##
############################################
output "latest_amazon_linux_2_ami_id" {
  value = data.aws_ami.latest_amazon_linux_2.id
}
####################################
## Create the actual Ec2 Instance ##
####################################
resource "aws_instance" "example" {
  ami           = data.aws_ami.latest_amazon_linux_2.id # Feed it the AMI you found
  instance_type = "t2.micro"                # Choose the size/type of compute you want
  iam_instance_profile = "SSMInstanceProfile" # Your Amazon Systems Manager Role
  key_name      = "dev-example-key"           # Here is the public key you want for ssh.
  subnet_id     = aws_subnet.example.id       # Put it on the Subnet you created.
  tags = {
    Name = "dev-amazon2023"
  }  
  
  root_block_device {
    volume_size = 30    # If you wanted to increase the hard drive space here it is.
    volume_type = "gp3" # The type of storage you want to use.
    encrypted   = true
  }
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.example.id # Add the security group you created.
  ]
  user_data = <<EOF
#!/bin/bash
### Standard Patching
sudo dnf --assumeyes update

### Install Firewalld ###
sudo dnf --assumeyes install firewalld
sudo systemctl enable firewalld --now
sudo firewall-cmd --zone=public --permanent --add-service=ssh
sudo firewall-cmd --zone=public --permanent --add-service=http
sudo firewall-cmd --zone=public --permanent --add-service=https
sudo systemctl reload firewalld

### Intall Nginx ###
sudo dnf --assumeyes install nginx
sudo systemctl enable nginx --now

### Configure Nginx ###
sudo rm /usr/share/nginx/html/index.html
sudo touch /usr/share/nginx/html/index.html
sudo chown -R  nginx:nginx /usr/share/nginx/html

sudo cat > /usr/share/nginx/html/index.html << EOF1
<html>
    <head>
        <title>Welcome to Test Website!</title>
    </head>
    <body>
        <p>It works!  Thank you for visiting</b>!</p>
    </body>
</html>
EOF
}
###############################################
## Print the Public IP to the Console Screen ##
###############################################
output "public_ip" {
  value = aws_instance.example.public_ip  # This will print on the screen what Public IP we need to ssh to.
}
