#!/bin/bash
sudo apt update
sudo apt install -y curl gnupg lsb-release apt-transport-https

# Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker adiluser

# kubectl
curl -LO https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl
sudo install kubectl /usr/local/bin/kubectl

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

set -euo pipefail

echo "Installation des dépendances Kubernetes..."
apt-get update
apt-get install -y \
  conntrack \
  socat \
  ebtables \
  iptables \
  curl \
  cri-tools

echo "Vérification des binaires requis..."
command -v conntrack
command -v crictl

set -euo pipefail

echo "Installation des dépendances système..."
apt-get update
apt-get install -y \
  conntrack \
  socat \
  ebtables \
  iptables \
  curl \
  gpg

echo "Installation de crictl..."
CRICTL_VERSION="v1.30.0"
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz \
  | tar -C /usr/local/bin -xz
chmod +x /usr/local/bin/crictl

echo "Installation de kubelet / kubeadm / kubectl..."
K8S_VERSION="1.34"

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "Vérification des binaires requis..."
command -v conntrack
command -v crictl
command -v kubelet
command -v kubectl

echo "Démarrage de Minikube (driver=none)..."
minikube start --driver=none

echo "Minikube est prêt !"
kubectl get nodes

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ArgoCD
kubectl create namespace argocd || true
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace

# Prometheus & Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus -n monitoring --create-namespace
helm install grafana grafana/grafana -n monitoring

# Récupération des mots de passe
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > /home/adiluser/argocd_password.txt
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d > /home/adiluser/grafana_password.txt
sudo chown adiluser:adiluser /home/adiluser/*.txt
