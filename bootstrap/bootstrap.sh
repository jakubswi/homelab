#!/bin/bash
set -e

echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ArgoCD manifests..."
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD CRDs to register..."
sleep 5

echo "Applying GitOps root application..."
kubectl apply -f clusters/home/root-app.yaml

echo "Bootstrap complete!"
