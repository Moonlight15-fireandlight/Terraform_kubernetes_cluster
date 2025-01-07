resource "aws_nat_gateway" "natgw_terraform" { #para el caso del modelo bastion - private server este se encontrara en la subred privada
  allocation_id = var.allocation_id
  
  subnet_id     = var.subnet_id

  tags = {
    Name = "NATGATEWAY_TERRAFORM"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  #depends_on = [ aws_internet_gateway.igw_terraform ] # para llevarlo a modulo es necesario establecer un depend on para otro modulo
}