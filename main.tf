
#infraestructura para 1 master node y n worker nodesy

#module "cluster_minikube" {
#
  #cambiar file yaml
#}

module "minikube_cluster" {

  source              = "./modules/minikubeinf"

  vpc_cidr            = "172.16.0.0/16"

  cidr_pub_subnets    = "172.16.0.0/20" 

  my_publicip         = "179.6.168.10/32"

  instance_type       = "t2.medium"

  vpc_dns             = "true"

  #kubectl_version     = "1.31.0"

  #kubernetes_version  = "1.32.0"

}

