output "bastion_public_ip" {
    
    value = module.kubernetes_infraestructure.bastion_public_ip
  
}

output "master_node_ip" {
    
    value = module.kubernetes_infraestructure.master_note_ip
  
}

output "worker_node_ip" {

    value = module.kubernetes_infraestructure.worker_node_ip

}

#output "server_ubuntu" {

#    value = module.server_ubuntu.server_public_ip
  
#}