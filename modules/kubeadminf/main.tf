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

  #count             = length(var.cidr_pub_subnets)

  cidr_block        = var.cidr_pub_subnets

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

  subnet_id     = aws_subnet.publicsunet.id # el NAT gateway se encontra en el primer subnet de la lista del variable

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
  
  #count = length(var.cidr_pub_subnets)

  subnet_id      = aws_subnet.publicsunet.id 
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "toprivate" {

  count = length(var.cird_priv_subnets)

  subnet_id      = aws_subnet.privatesubnet[count.index].id
  route_table_id = aws_route_table.private.id
}

# Deploy EC2 AWS

resource "aws_instance" "bastion_server" {

  #count = length(var.cidr_pub_subnets)
  #name = "terraform-testing" #agregar un nombre a la instancia

  #Numero de servidores en base al tipo de instancias que se muestra en la variable instance type
  #count = length(var.instance_type)

  ami           = var.ami
  instance_type = "t2.micro"
  key_name      = "DockerOregon"


  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "bastion-server"

  }

  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  subnet_id              = aws_subnet.publicsunet.id # solo habra 1 bastion para los master y wokrer nodes
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

  associate_public_ip_address = true


  #depends_on = [ aws_internet_gateway.igw ] #Como exportar esto

}

resource "aws_security_group" "bastion_security_group" {

  name = "BastionSG"

  description = "Grupo de seguridad establecido para el Bastion"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id

}

resource "aws_security_group_rule" "bastion_security_group_rule_ingress" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  cidr_blocks       = ["0.0.0.0/0"]
  
  security_group_id = aws_security_group.bastion_security_group.id

  description       = "Bastion Server to kubernetes"
  
}

resource "aws_security_group_rule" "bastion_security_group_rule_egress" {

  type              = "egress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  cidr_blocks       = [ var.vpc_cidr ]
  
  security_group_id = aws_security_group.bastion_security_group.id

  description       = "Bastion Server to kubernetes"
  
}

resource "aws_instance" "master_nodes" {

  count = var.number_master_nodes
  #count = length(var.cird_priv_subnets)


  ami           = var.ami
  instance_type = var.nodes_instance_type
  key_name      = "DockerOregon"
  #user_data     = file("./kubeadmuserdata.sh")

  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "master-node-${count.index + 1}"

  }

  vpc_security_group_ids = [ aws_security_group.master_node_security_group.id ]
  subnet_id              = aws_subnet.privatesubnet[0].id
  

  associate_public_ip_address = false

}

resource "aws_security_group" "master_node_security_group" {

  name = "master-node-security-group"

  description = "Grupo de seguridad configurado para el servidor principal"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id

}

resource "aws_security_group_rule" "Kubernetes-API-server" {

  type              = "ingress"
  
  from_port         = 6443
  
  to_port           = 6443
  
  protocol          = "tcp"
  
  cidr_blocks       = ["0.0.0.0/0"]
  
  security_group_id = aws_security_group.master_node_security_group.id

  description       = "Kubernetes Api Server"

}

resource "aws_security_group_rule" "etcd-server" {

  type              = "ingress"
  
  from_port         = 2379
  
  to_port           = 2380
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  source_security_group_id = aws_security_group.master_node_security_group.id

  description       = "etcd server client API"

}

resource "aws_security_group_rule" "Kubelet" {

  type              = "ingress"
  
  from_port         = 10250
  
  to_port           = 10250
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  source_security_group_id = aws_security_group.master_node_security_group.id

  description       = "Kubelet API"

}

resource "aws_security_group_rule" "kube-scheduler" {

  type              = "ingress"
  
  from_port         = 10259
  
  to_port           = 10259
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  source_security_group_id = aws_security_group.master_node_security_group.id

  description       = "kube-scheduler"

}

resource "aws_security_group_rule" "kube-controller-manager" {

  type              = "ingress"
  
  from_port         = 10257
  
  to_port           = 10257
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  source_security_group_id = aws_security_group.master_node_security_group.id

  description       = "kube-controller-manager"

}

resource "aws_security_group_rule" "ssh-from-bastion-ingress" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  source_security_group_id = aws_security_group.bastion_security_group.id

  description       = "SSH from bastion"

}

resource "aws_security_group_rule" "port-weave-net-01" {

  type              = "ingress"
  
  from_port         = 6783
  
  to_port           = 6783
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 1 to CNI weavenet"

}

resource "aws_security_group_rule" "port-weave-net-02" {

  type              = "ingress"
  
  from_port         = 6783
  
  to_port           = 6783
  
  protocol          = "udp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 2 to CNI weavenet"

}

resource "aws_security_group_rule" "port-weave-net-03" {

  type              = "ingress"
  
  from_port         = 6784
  
  to_port           = 6784
  
  protocol          = "udp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 3 to CNI weavenet"

}

resource "aws_security_group_rule" "egress-rule01" {

  type              = "egress"
  
  from_port         = 80
  
  to_port           = 80
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  #source_security_group_id = aws_security_group.bastion_security_group.id

  cidr_blocks       = [ "0.0.0.0/0" ]

  #description       = "SSH from bastion"

}

resource "aws_security_group_rule" "egress-rule02" {

  type              = "egress"
  
  from_port         = 0
  
  to_port           = 65535
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  #source_security_group_id = aws_security_group.bastion_security_group.id

  cidr_blocks       = [ var.vpc_cidr ]

  #description       = "SSH from bastion"

}

resource "aws_security_group_rule" "egress-rule03" {

  type              = "egress"
  
  from_port         = 6443
  
  to_port           = 6443
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  #source_security_group_id = aws_security_group.bastion_security_group.id

  cidr_blocks       = [ "0.0.0.0/0" ]

  #description       = "SSH from bastion"

}

resource "aws_security_group_rule" "egress-rule04" {

  type              = "egress"
  
  from_port         = 10250
  
  to_port           = 10250
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  #source_security_group_id = aws_security_group.bastion_security_group.id

  cidr_blocks       = [ var.vpc_cidr ]

  #description       = "SSH from bastion"

}

resource "aws_security_group_rule" "egress-rule05" {

  type              = "egress"
  
  from_port         = 443
  
  to_port           = 443
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.master_node_security_group.id

  #source_security_group_id = aws_security_group.bastion_security_group.id

  cidr_blocks       = [ "0.0.0.0/0" ]

  #description       = "SSH from bastion"

}

resource "aws_instance" "worker_nodes" {

  count = var.number_worker_nodes
  #count = length(var.cird_priv_subnets)


  ami           = var.ami
  instance_type = var.nodes_instance_type
  key_name      = "DockerOregon"
  #user_data     = file("./kubeadmuserdata.sh")

  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "worker-node-${count.index + 1}"

  }

  vpc_security_group_ids = [ aws_security_group.worker_nodes_security_group.id ]
  subnet_id              = aws_subnet.privatesubnet[0].id
  

  associate_public_ip_address = false

}


resource "aws_security_group" "worker_nodes_security_group" {

  name = "worker-node-security-group"

  description = "Grupo de seguridad configurado para el servidor principal"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id

}

resource "aws_security_group_rule" "worker-kubelet-API" {
  type      = "ingress"
  from_port = 10250
  to_port   = 10250
  protocol  = "tcp"
  #cidr_blocks       = [ aws_security_group.bastion_sg.id ]
  source_security_group_id = aws_security_group.master_node_security_group.id
  security_group_id        = aws_security_group.worker_nodes_security_group.id
  description = "Kubelet API"
}

resource "aws_security_group_rule" "kube-proxy" {
  type      = "ingress"
  from_port = 10256
  to_port   = 10256
  protocol  = "tcp"
  #cidr_blocks       = [ aws_security_group.bastion_sg.id ]
  source_security_group_id = aws_security_group.worker_nodes_security_group.id
  security_group_id        = aws_security_group.worker_nodes_security_group.id
  description = "kube-proxy"
}

resource "aws_security_group_rule" "services" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker_nodes_security_group.id
  description       = "NodePort Services"
}

resource "aws_security_group_rule" "bastion-ssh-ingress" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.worker_nodes_security_group.id

  source_security_group_id = aws_security_group.bastion_security_group.id

  description       = "SSH from bastion"

}

resource "aws_security_group_rule" "worker-port-weave-net-01" {

  type              = "ingress"
  
  from_port         = 6783
  
  to_port           = 6783
  
  protocol          = "tcp"
  
  security_group_id = aws_security_group.worker_nodes_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 1 to CNI weavenet"

}

resource "aws_security_group_rule" "worker-port-weave-net-02" {

  type              = "ingress"
  
  from_port         = 6783
  
  to_port           = 6783
  
  protocol          = "udp"
  
  security_group_id = aws_security_group.worker_nodes_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 2 to CNI weavenet"

}

resource "aws_security_group_rule" "worker-port-weave-net-03" {

  type              = "ingress"
  
  from_port         = 6784
  
  to_port           = 6784
  
  protocol          = "udp"
  
  security_group_id = aws_security_group.worker_nodes_security_group.id

  cidr_blocks       = ["0.0.0.0/0"]

  description       = "rule 3 to CNI weavenet"

}


resource "aws_security_group_rule" "egress-worker-rule01" {

  type              = "egress"

  from_port         = 80

  to_port           = 80

  protocol          = "tcp"

  cidr_blocks       = ["0.0.0.0/0"]

  security_group_id = aws_security_group.worker_nodes_security_group.id

}

resource "aws_security_group_rule" "egress-worker-rule02" {

  type              = "egress"

  from_port         = 443

  to_port           = 443

  protocol          = "tcp"

  cidr_blocks       = ["0.0.0.0/0"]

  security_group_id = aws_security_group.worker_nodes_security_group.id

}

resource "aws_security_group_rule" "egress-worker-rule03" {

  type              = "egress"

  from_port         = 6443

  to_port           = 6443

  protocol          = "tcp"

  cidr_blocks       = ["0.0.0.0/0"]

  security_group_id = aws_security_group.worker_nodes_security_group.id

}


output "bastion_public_ip" {

  value = aws_instance.bastion_server.public_ip
  
}

#output "master_node_private_ip" {

#  value = aws_instance.master_nodes.
  
#}

#output "worker_node_private_ip" {

#  value = aws_instance.worker_nodes
  
#}