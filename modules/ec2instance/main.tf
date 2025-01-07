data "aws_ami" "ubuntu" {

  most_recent = true             #la version mas reciente
  owners      = ["099720109477"] #owner of the ami

}

resource "aws_instance" "instancelinux01" {

  count = length(var.subnet_id)
  #name = "terraform-testing" #agregar un nombre a la instancia

  #Numero de servidores en base al tipo de instancias que se muestra en la variable instance type
  #count = length(var.instance_type)

  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "DockerOregon"



  tags = {

    #Name = " ${var.region} - ${terraform.workspace} "
    Name = "server-terraform-${var.region}"

  }

  vpc_security_group_ids = [aws_security_group.securitygroup1.id]
  subnet_id              = var.subnet_id[count.index] # para una sola subred
  #subnet_id = module.vpc[each.key].public_subnets[*] #para lograr que una instancia este en su respectivo subred 

  associate_public_ip_address = true


  #depends_on = [ aws_internet_gateway.igw ] #Como exportar esto

}

resource "aws_security_group" "securitygroup1" {
  name = "terraform-ssh-access"

  description = "Allow ssh connect to virtual machine"

  #for_each = var.project

  vpc_id = var.vpc_id

  dynamic "ingress" {

    for_each = var.inbound_ports

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]

    }
  }

  dynamic "egress" {

    for_each = var.outbound_ports

    content {

      from_port = egress.value
      to_port   = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]

    }
    
  }

}




output "aws_instance_id" {

  value = aws_instance.instancelinux01.*.id

  #value = aws_instance.instancelinux01[each.key].public_ip
  #value = { for p in sort(keys(var.project)) : p => aws_instance.instancelinux01[p].public_ip }

  #insta = aws_instance.instancelinux01["terraform"].public_ip

}
