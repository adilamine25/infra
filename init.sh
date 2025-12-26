#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/init-devops.log"
exec > >(tee -a $LOG_FILE) 2>&1

USER="adiluser"

echo "📦 Mise à jour du système et installation des dépendances..."
sudo apt update
sudo apt install -y curl gnupg lsb-release apt-transport-https \
  conntrack socat ebtables iptables gpg software-properties-common

# Docker
echo "🐳 Installation de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --dearmor -o /etc/apt/keyrings/docker.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl enable docker --now

# kubectl
echo "🔧 Installation de kubectl..."
KUBECTL_VERSION="v1.30.0"
curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
sudo install kubectl /usr/local/bin/kubectl

# K3s
echo "🚀 Installation de K3s..."
curl -sfL https://get.k3s.io | sh -

# Vérification que K3s est actif
echo "⏳ Vérification que K3s est démarré..."
MAX_RETRIES=30
RETRY_COUNT=0
until sudo systemctl is-active --quiet k3s; do
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "❌ Erreur : K3s n'a pas démarré après $MAX_RETRIES essais."
        sudo journalctl -u k3s --no-pager
        exit 1
    fi
    echo "⏳ Attente que K3s soit actif... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT+1))
done
echo "✅ K3s est prêt !"

# Configurer kubectl pour l'utilisateur
mkdir -p /home/$USER/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/$USER/.kube/config
sudo chown $USER:$USER /home/$USER/.kube/config
export KUBECONFIG=/home/$USER/.kube/config

# Vérification des nœuds
kubectl get nodes

# Helm
echo "⛵ Installation de Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ArgoCD
echo "🚀 Installation de ArgoCD..."
kubectl create namespace argocd || true
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace

# Prometheus & Grafana
echo "📊 Installation de Prometheus et Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus -n monitoring --create-namespace
helm install grafana grafana/grafana -n monitoring

# Récupération des mots de passe
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > /home/$USER/argocd_password.txt
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d > /home/$USER/grafana_password.txt
sudo chown $USER:$USER /home/$USER/*.txt

echo "✅ Installation complète ! Les mots de passe sont dans /home/$USER/"
