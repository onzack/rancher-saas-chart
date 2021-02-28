# Rancher SaaS API
This repository contains the Helm Chart for ONZACK Rancher Software as a Service backend APIs

# Quick start

```
git clone https://github.com/onzack/rancher-saas-chart.git
kubectl create namespace rancher-saas-api
kubectl -n rancher-saas-api create secret tls ingress-cert-secret --cert=<Cert PEM contenct> --key=<Key PEM content>
cp ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas-api/values.yaml custom-values.yaml
vim custom-values.yaml
helm upgrade --install --create-namespace -n rancher-saas-api \
  -f custom-values.yaml \
  rancher-saas-api \
  ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas-api

```