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

resource "aws_eip" "eip_nat_terraform" {

  domain = "vpc" #Indicates if this EIP is for use in VPC

  tags = {

    Name = "EIP_TERRAFORM"

  }
}

resource "aws_subnet" "publicsunet" {

  vpc_id            = aws_vpc.main_vpc.id

  count             = length(var.cidr_pub_subnets)

  cidr_block        = var.cidr_pub_subnets[count.index]

  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {

               Name = "pubsunet_terraform"
  
  }
}

resource "aws_subnet" "privatesubnet" {

  vpc_id            = aws_vpc.main_vpc.id

  count             = length(var.cird_priv_subnets) # El numero de subredes privadas se obtendra de la lista de CIDRs

  cidr_block        = var.cird_priv_subnets[count.index]

  availability_zone = data.aws_availability_zones.available.names[1]
  #availability_zone = "${var.region}a" 

  tags = {

    Name = "privsubnet_terraform"
  
  }
}

resource "aws_nat_gateway" "natgw_terraform" {

  allocation_id = aws_eip.eip_nat_terraform.id

  subnet_id     = aws_subnet.publicsunet[0].id # el NAT gateway se encontra en el primer subnet de la lista del variable

  tags = {
    Name = "NATGATEWAY_TERRAFORM"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [ aws_internet_gateway.igw ]

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

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    #nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
    gateway_id = aws_nat_gateway.natgw_terraform.id
  }

  tags = {
    Name = "routetable_private_terraform"
  }

  depends_on  = [ aws_subnet.privatesubnet ]
}

resource "aws_route_table_association" "topublic" {
  
  count = length(var.cidr_pub_subnets)

  subnet_id      = aws_subnet.publicsunet[count.index].id 
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "toprivate" {

  count = length(var.cird_priv_subnets)

  subnet_id      = aws_subnet.privatesubnet[count.index].id
  route_table_id = aws_route_table.private.id
}

# Deploy EC2 AWS

resource "aws_instance" "public_server" {

  count = length(var.cidr_pub_subnets)
  #name = "terraform-testing" #agregar un nombre a la instancia

  #Numero de servidores en base al tipo de instancias que se muestra en la variable instance type
  #count = length(var.instance_type)

  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "DockerOregon"


  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "bastion-server"

  }

  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  subnet_id              = aws_subnet.publicsunet[count.index].id
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

  associate_public_ip_address = true


  #depends_on = [ aws_internet_gateway.igw ] #Como exportar esto

}

resource "aws_instance" "nodes_servers" {

  count = var.private_number_instances
  #count = length(var.cird_priv_subnets)


  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "DockerOregon"

  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "kubernetes-node-${count.index}"

  }

  vpc_security_group_ids = [ aws_security_group.nodes_security_group.id ]
  subnet_id              = aws_subnet.privatesubnet[0].id
  

  associate_public_ip_address = false

}

resource "aws_security_group" "nodes_security_group" {

  name = "BastionSG"

  description = "Grupo de seguridad establecido para el Bastion"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id

  dynamic "ingress" {

    for_each = var.bastion_inbound_ports

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]

    }
  }

  dynamic "egress" {

    for_each = var.bastion_outbound_ports

    content {

      from_port = egress.value
      to_port   = egress.value
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]

    }
    
  }

}

resource "aws_security_group" "server_security_group" {

  name = "Server-sg"

  description = "Grupo de seguridad configurado para el servidor principal"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id

}

resource "aws_security_group_rule" "private_sg_ingress_rule" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  #cidr_blocks       = [ aws_security_group.bastion_sg.id ]
  source_security_group_id = aws_security_group.bastion_security_group.id
  security_group_id        = aws_security_group.server_security_group.id
}

resource "aws_security_group_rule" "private_sg_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.server_security_group.id
}


output "bastion_public_ip" {

  value = aws_instance.public_server.*.public_ip
  
}

output "private" {

  value = aws_instance.private_server.*.private_ip
  
}