# Rancher SaaS API
This repository contains the Helm Chart for ONZACK Rancher Software as a Service backend APIs

# Quick start

```
git clone https://github.com/onzack/rancher-saas-chart.git
kubectl create namespace rancher-saas-ops
kubectl -n rancher-saas-ops create secret tls ingress-cert-secret --cert=<Cert PEM contenct> --key=<Key PEM content>
cp ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas-ops/values.yaml custom-values.yaml
vim custom-values.yaml
helm upgrade --install --create-namespace -n rancher-saas-ops \
  -f custom-values.yaml \
  rancher-saas-ops \
  ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas-ops

```