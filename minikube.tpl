#!/bin/bash 

# install minikube

curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64

sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

# instalar docker

sudo apt-get update

sudo apt-get install ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce

# Establecer docker sin usar el usuario sudo

sudo usermod -aG docker ubuntu && newgrp docker

#testing templatefile

echo " testing my template variables ${kubectl_version} and ${kubernetes_version} " > /home/ubuntu/testing.txt 

kubectlversion=${kubectl_version}

kubernetesversion=${kubernetes_version}

echo " minikube start --driver=docker --nodes 2 -p multinode-demo --kubernetes-version $kubernetesversion " > /home/ubuntu/minikube.txt

# Instalar kubectl
# version 1.32.0
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
 
curl -LO "https://dl.k8s.io/release/$kubectlversion/bin/linux/amd64/kubectl"

curl -LO "https://dl.k8s.io/release/$kubectlversion/bin/linux/amd64/kubectl.sha256"

#echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check (validar)

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# deploy minikube

#minikube start --driver=docker --nodes 2 -p multinode-demo --kubernetes-version $kubernetesversion