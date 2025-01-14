
#infraestructura para 1 master node y n worker nodesy

module "deploy_kubernetes_infraestructure" {

  source              = "./modules/vpcaws"
  vpc_cidr            = "172.16.0.0/16"
  cidr_pub_subnets    = "172.16.0.0/20" 
  cird_priv_subnets   = [ "172.16.16.0/20" ]
  region              = "us-west-2"
  nodes_instance_type = "t2.medium"
  vpc_dns             = "true"
  number_master_nodes = 1
  number_worker_nodes = 1
  #vpc_dns = false # argumento opcional
}


# tiene que ser opcional nat gateway

