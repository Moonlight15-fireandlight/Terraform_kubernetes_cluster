data "aws_availability_zones" "available" {

  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }

}

data "aws_ami" "ubuntu" {

  most_recent = true             #la version mas reciente
  owners      = ["099720109477"] #owner of the ami

}

resource "aws_vpc" "main_vpc" {

  cidr_block = var.vpc_cidr
  
  enable_dns_hostnames = var.vpc_dns

  tags = {
    Name = "vpc_terraform"
  }

}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main_vpc.id #ya incluye el attachment al VPC

  tags = {
    Name = "igw_terraform"
  }
}

resource "aws_subnet" "publicsunet" {

  vpc_id            = aws_vpc.main_vpc.id

  #count             = length(var.cidr_pub_subnets)

  cidr_block        = var.cidr_pub_subnets

  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {

               Name = "pubsunet_terraform"
  
  }
}

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main_vpc.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id

  }

  tags = {
    Name = "routetable_public_terraform"
  }

  depends_on = [ aws_subnet.publicsunet ]

}

resource "aws_route_table_association" "topublic" {
  
  #count = length(var.cidr_pub_subnets)

  subnet_id      = aws_subnet.publicsunet.id 
  route_table_id = aws_route_table.public.id

}

#https://developer.hashicorp.com/terraform/language/functions/templatefile
#https://developer.hashicorp.com/terraform/language/expressions/strings#string-templates
#https://stackoverflow.com/questions/50835636/accessing-terraform-variables-within-user-data-provider-template-file
#https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file

data "template_file" "init" {
  
  template = file("./minikube.tpl")

  vars = {
    kubectl_version     = var.kubectl_version
    kubernetes_version  = var.kubernetes_version # de por si la version de kubectl debe ser igual o 1 menor
  }
  
}

resource "aws_instance" "minikube_server" {

  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "DockerOregon"
  user_data     = data.template_file.init.rendered
  #user_data     = templatefile("./minikube.sh", {kubectl_version=var.kubectl_version,kubernetes_version=var.kubernetes_version})

  tags = {
    Name = "minikube"
  }

  vpc_security_group_ids = [ aws_security_group.minikube_security_group.id ]
  subnet_id              = aws_subnet.publicsunet.id # solo habra 1 bastion para los master y wokrer nodes
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 
  


  associate_public_ip_address = true


  #depends_on = [ aws_internet_gateway.igw ] #Como exportar esto

}

resource "aws_security_group" "minikube_security_group" {

  name = "minikube_security_group"

  description = "Grupo de seguridad establecido para el servidor minikube"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id
  
}

resource "aws_security_group_rule" "connect_to_ssh" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  cidr_blocks       = [ var.my_publicip ]
  
  security_group_id = aws_security_group.minikube_security_group.id

  description       = "ssh to minikube"
  
}

resource "aws_security_group_rule" "ingress_http" {

  type              = "ingress"
  
  from_port         = 80
  
  to_port           = 80
  
  protocol          = "tcp"
  
  cidr_blocks       = [ "0.0.0.0/0" ]
  
  security_group_id = aws_security_group.minikube_security_group.id

  description       = "http to minikube"
  
}

resource "aws_security_group_rule" "ingress_https" {

  type              = "ingress"
  
  from_port         = 443
  
  to_port           = 443
  
  protocol          = "tcp"
  
  cidr_blocks       = [ "0.0.0.0/0" ]
  
  security_group_id = aws_security_group.minikube_security_group.id

  description       = "https to minikube"
  
}


resource "aws_security_group_rule" "egress_rules_minikube" {

    type        = "egress"

    from_port   = 0

    to_port     = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = aws_security_group.minikube_security_group.id
  
    description = "minikube egress rules"

}


output "minikube_public_ip" {

  value = aws_instance.minikube_server.public_ip
  
}


