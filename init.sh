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
  curl

echo "Démarrage de Minikube (driver=none)..."
minikube start --driver=none

echo "Vérification du cluster Kubernetes..."
MAX_RETRIES=30
RETRY_COUNT=0

until kubectl cluster-info > /dev/null 2>&1; do
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "Erreur : le cluster Minikube n'a pas démarré après $MAX_RETRIES essais."
        exit 1
    fi
    echo "Attente que Minikube soit prêt... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

echo "✅ Minikube est prêt"
kubectl get nodes


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
