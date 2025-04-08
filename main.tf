
#infraestructura para 1 master node y n worker nodesy

#module "deploy_kubernetes_infraestructure" {

#  source              = "./modules/vpcaws"
#  vpc_cidr            = "172.16.0.0/16"
#  cidr_pub_subnets    = "172.16.0.0/20" 
#  cird_priv_subnets   = [ "172.16.16.0/20" ]
#  region              = "us-west-2"
#  nodes_instance_type = "t2.medium"
#  vpc_dns             = "true"
#  number_master_nodes = 1
#  number_worker_nodes = 1
#  #vpc_dns = false # argumento opcional
#}

#APUNTAR EL DOMINIO AL HOST (SERVIDOR )

module "minikube" {

  source            = "./modules/minikube"
  vpc_cidr          = "172.16.0.0/16"
  vpc_dns           = "true"
  cidr_pub_subnets  = "172.16.0.0/20"
  mypublicip        = "179.6.168.10/32"
  instance_type     = "t2.medium"

}

#module "upload_images_s3" {

  #source = "./modules/storage_s3"

#}

# tiene que ser opcional nat gateway

#minikube start --driver=docker --nodes 2 -p multinode-demo --kubernetes-version v1.32.0

# module "server_ubuntu" {

#  source            = "./modules/ec2instance"
#  vpc_cidr          = "172.16.0.0/16"
#  vpc_dns           = "true"
#  cidr_pub_subnets  = "172.16.0.0/20"
#  instance_type     = "t2.medium" #deberia ser micro

#}
