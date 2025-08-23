output "bastion_public_ip" {

  value = aws_instance.bastion_server.public_ip
  
}

output "master_note_ip" {

    value = aws_instance.controlplane_server.private_ip
  
}

output "worker_node_ip" {
  
    value = aws_instance.workernode_server.private_ip

}