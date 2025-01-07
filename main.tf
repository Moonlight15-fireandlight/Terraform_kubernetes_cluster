module "deploy_kubernetes_infraestructure" {

  source            = "./modules/vpcaws"
  vpc_cidr          = "172.16.0.0/16"
  cidr_pub_subnets  = [ "172.16.0.0/20" ] 
  cird_priv_subnets = [ "172.16.16.0/20" ]
  region            = "us-west-2"
  instance_type     = "t2.micro"
  vpc_dns           = "true"
  private_number_instances  = 2 #2 nodes (1 master y worker node)
  

  #vpc_dns = false # argumento opcional
}


# tiene que ser opcional nat gateway

