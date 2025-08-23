data "aws_availability_zones" "available" {

  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }

}

#data "aws_ami" "ubuntu" {

 # most_recent = true             #la version mas reciente
 # owners      = ["099720109477"] #owner of the ami

#}

resource "aws_vpc" "main_vpc" {

  cidr_block = var.vpc_cidr
  
  enable_dns_hostnames = var.vpc_dns

  tags = {
    Name = "terraform_vpc"
  }

}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main_vpc.id #ya incluye el attachment al VPC

  tags = {

        Name = "terraform_igw"
  
  }
}

resource "aws_subnet" "publicsubnet" {

  vpc_id            = aws_vpc.main_vpc.id

  #count             = length(var.cidr_pub_subnets)

  cidr_block        = var.cidr_pub_subnet #

  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = true #Asigna por default una ip publica a las instancias creadas dentro de esta subnet

  tags = {

        Name = "terraform_public_subnet"
  
  }

}

resource "aws_subnet" "privsubnet" {

  vpc_id            = aws_vpc.main_vpc.id

  #count             = length(var.cidr_pub_subnets)

  cidr_block        = var.cidr_priv_subnet 

  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = false

  tags = {

        Name = "terraform_private_subnet"
  
  }

}

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main_vpc.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id

  }

  tags = {

    Name = "terraform_public_routetable"
  
  }

  #depends_on = [ aws_subnet.publicsunet ]

}

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main_vpc.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_nat_gateway.nat_gw.id

  }

  tags = {

    Name = "terraform_private_routetable"
  
  }

  #depends_on = [ aws_subnet.privsubnet ]

}

resource "aws_route_table_association" "topublic" {
  
  #count = length(var.cidr_pub_subnets)

  subnet_id      = aws_subnet.publicsubnet.id 

  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "toprivate" {
  
  #count = length(var.cidr_pub_subnets)

  subnet_id      = aws_subnet.privsubnet.id

  route_table_id = aws_route_table.private.id

}

#Creacion del Elastic IP
resource "aws_eip" "nat_eip" {

  vpc = true

  tags = {

    Name = "terraform_eip"

  }

}

resource "aws_nat_gateway" "nat_gw" {

  allocation_id = aws_eip.nat_eip.id
  
  subnet_id     = aws_subnet.publicsubnet.id

  tags = {

    Name = "terraform_nat_gw"

  }

# To ensure proper ordering, it is recommended to add an explicit dependency on the Internet Gateway for the VPC.
  
  depends_on = [
    
    aws_internet_gateway.igw
  
  ]
}

resource "aws_instance" "bastion_server" {

  ami           = var.ami
  instance_type = var.bastion_instance_type
  key_name      = "DockerOregon"
  #user_data     = data.template_file.init.rendered
  #user_data     = templatefile("./minikube.sh", {kubectl_version=var.kubectl_version,kubernetes_version=var.kubernetes_version})

  tags = {

    Name = " Bastion "
  
  }

  vpc_security_group_ids = [ aws_security_group.bastion_security_group.id ]
  subnet_id              = aws_subnet.publicsubnet.id # solo habra 1 bastion para los master y wokrer nodes
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

}

resource "aws_security_group" "bastion_security_group" {

  name = "bastion_security_group"

  description = "Grupo de seguridad establecido para el bastion"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id
  
}

resource "aws_security_group_rule" "connect_to_ssh" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  #cidr_blocks       = [ var.mypublicip ]

  cidr_blocks       = [ "0.0.0.0/0" ]
  
  security_group_id = aws_security_group.bastion_security_group.id

  description       = "ssh to bastion"
  
}

resource "aws_security_group_rule" "bastion_all_egress" {

  type              = "egress"
  
  from_port         = 0
  
  to_port           = 0
  
  protocol          = "-1"
  
  #cidr_blocks       = [ var.mypublicip ]

  cidr_blocks       = [ "0.0.0.0/0" ]
  
  security_group_id = aws_security_group.bastion_security_group.id

  description       = "ssh to bastion egress"
  
}

resource "aws_instance" "controlplane_server" {

  ami           = var.ami
  instance_type = var.nodes_instance_type
  key_name      = "DockerOregon"
  #user_data     = data.template_file.init.rendered
  #user_data     = templatefile("./minikube.sh", {kubectl_version=var.kubectl_version,kubernetes_version=var.kubernetes_version})

  tags = {
    Name = "Masternode"
  }

  vpc_security_group_ids = [ aws_security_group.control_plane_security_group.id ]
  subnet_id              = aws_subnet.privsubnet.id # solo habra 1 bastion para los master y wokrer nodes
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

}

resource "aws_security_group" "control_plane_security_group" {

  name = "master_node_security_group"

  description = "Grupo de seguridad establecido para el masternode"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id
  
}

resource "aws_security_group_rule" "connect_to_ssh_to_master" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22
  
  protocol          = "tcp"
  
  #cidr_blocks       = [ var.mypublicip ]

  source_security_group_id = aws_security_group.bastion_security_group.id
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "ssh to masternode"
  
}

resource "aws_security_group_rule" "Api_server" {

  type              = "ingress"
  
  from_port         = 6443
  
  to_port           = 6443
  
  protocol          = "tcp"
  
  cidr_blocks       = [ "0.0.0.0/0" ]
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "Kubernetes Api Server"
  
}

resource "aws_security_group_rule" "etcd-server" {

  type              = "ingress"
  
  from_port         = 2379
  
  to_port           = 2380
  
  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "etcd server client API"
  
}

resource "aws_security_group_rule" "kubelet-API" {

  type              = "ingress"
  
  from_port         = 10250
  
  to_port           = 10250
  
  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "KUBELET-API"
  
}

resource "aws_security_group_rule" "kube-scheduler" {

  type              = "ingress"
  
  from_port         = 10259
  
  to_port           = 10259
  
  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "KUBE-SCHEDULER"
  
}


resource "aws_security_group_rule" "kube-controller-manager" {

  type              = "ingress"
  
  from_port         = 10257
  
  to_port           = 10257
  
  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.control_plane_security_group.id

  description       = "kube-controller-manager"
  
}

resource "aws_security_group_rule" "egress_master_node_http" {

    type        = "egress"

    from_port   = 80

    to_port     = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = aws_security_group.control_plane_security_group.id
  
    description = "Master node to reach internet"

}

resource "aws_security_group_rule" "egress_master_node_https" {

    type        = "egress"

    from_port   = 443

    to_port     = 443

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = aws_security_group.control_plane_security_group.id
  
    description = "Master node to reach internet on port 443"

}

resource "aws_security_group_rule" "egress_master_node_control_plane" {

    type        = "egress"

    from_port   = 6443

    to_port     = 6443

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = aws_security_group.control_plane_security_group.id
  
    description = "To reach control plane"

}

resource "aws_security_group_rule" "egress_master_node_kubelet" {

    type        = "egress"

    from_port   = 10250

    to_port     = 10250

    protocol = "tcp"

    cidr_blocks = [ var.vpc_cidr ]

    security_group_id = aws_security_group.control_plane_security_group.id
  
    description = " Kuber api server to reach kubelet"

}

resource "aws_security_group_rule" "master_node_all" {

    type        = "egress"

    from_port   = 0

    to_port     = 0

    protocol    = "-1"

    cidr_blocks = [var.vpc_cidr]

    security_group_id = aws_security_group.control_plane_security_group.id
  
    description = " Allows communicaation between different control plane "

}

resource "aws_instance" "workernode_server" {

  ami           = var.ami
  instance_type = var.nodes_instance_type
  key_name      = "DockerOregon"
  #user_data     = data.template_file.init.rendered
  #user_data     = templatefile("./minikube.sh", {kubectl_version=var.kubectl_version,kubernetes_version=var.kubernetes_version})

  tags = {

    Name = "WorkerNode"
  
  }

  vpc_security_group_ids = [ aws_security_group.worker_node_security_group.id ]
  subnet_id              = aws_subnet.privsubnet.id # solo habra 1 bastion para los master y wokrer nodes
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

}

resource "aws_security_group" "worker_node_security_group" {

  name = "worker_node_security_group"

  description = "Grupo de seguridad establecido para el workernode"

  #for_each = var.project

  vpc_id = aws_vpc.main_vpc.id
  
}

resource "aws_security_group_rule" "bastion_worker_node" {

  type              = "ingress"
  
  from_port         = 22
  
  to_port           = 22

  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.bastion_security_group.id
  
  security_group_id = aws_security_group.worker_node_security_group.id

  description       = "Conecction to ssh"
  
}

resource "aws_security_group_rule" "kubelet_API" {

  type              = "ingress"
  
  from_port         = 10250
  
  to_port           = 10250

  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.worker_node_security_group.id

  description       = "Kubelet API"
  
}

resource "aws_security_group_rule" "kube-proxy" {

  type              = "ingress"
  
  from_port         = 10256
  
  to_port           = 10256

  protocol          = "tcp"
  
  source_security_group_id = aws_security_group.control_plane_security_group.id
  
  security_group_id = aws_security_group.worker_node_security_group.id

  description       = "Conecction to kube-proxy"
  
}

resource "aws_security_group_rule" "nodeport_services_tcp" {

  type              = "ingress"
  
  from_port         = 30000
  
  to_port           = 32767

  protocol          = "tcp"
  
  cidr_blocks       = ["0.0.0.0/0"]
  
  security_group_id = aws_security_group.worker_node_security_group.id

  description       = "NodePort Services"
  
}

resource "aws_security_group_rule" "nodeport_services_udp" {

  type              = "ingress"
  
  from_port         = 30000
  
  to_port           = 32767

  protocol          = "udp"
  
  cidr_blocks       = ["0.0.0.0/0"]
  
  security_group_id = aws_security_group.worker_node_security_group.id

  description       = "nodeport Services"
  
}


resource "aws_security_group_rule" "worker_node_http" {

    type        = "egress"

    from_port   = 80

    to_port     = 80

    protocol    = "tcp"

    cidr_blocks       = ["0.0.0.0/0"]

    security_group_id = aws_security_group.worker_node_security_group.id
  
    description       = "Master node to reach internet"

}

resource "aws_security_group_rule" "worker_node_https" {

    type        = "egress"

    from_port   = 443

    to_port     = 443

    protocol    = "tcp"

    cidr_blocks       = ["0.0.0.0/0"]

    security_group_id = aws_security_group.worker_node_security_group.id
  
    description       = "Master node to reach internet on port 443"

}

resource "aws_security_group_rule" "worker_node_apiport" {

    type              = "egress"

    from_port         = 6443

    to_port           = 6443

    protocol          = "tcp"

    cidr_blocks       = ["0.0.0.0/0"]

    security_group_id = aws_security_group.worker_node_security_group.id
  
    description       = "Worker node to reach control plane"

}

resource "aws_security_group_rule" "worker_node_all" {

    type              = "egress"

    from_port         = 0

    to_port           = 0

    protocol          = "-1"

    cidr_blocks       = [var.vpc_cidr]

    security_group_id = aws_security_group.worker_node_security_group.id
  
    description       = "Allows communication between worker nodes on all protocol"

}

