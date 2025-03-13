output "minikube_public_ip" {

  value = aws_instance.minikube_server.public_ip
  
}