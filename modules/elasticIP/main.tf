resource "aws_eip" "lb" {

  count = length(var.instance_aws)
  #instance = aws_instance.web.id
  instance = var.instance_aws[count.index]
  domain   = "vpc"
  
}