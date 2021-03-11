# ONZACK Rancher Software as a Service Helm Chart
This repository contains the Code for ONZACK Rancher Software as a Service.    

# Quick Start

Prerequisites:
- Kubernetes cluster with an Ingress Controller
- A loadbalancer or DNS entry for *.rancher.example.com pointing to your cluster
- TLS keys and certificates

Make sure to replace *.rancher.example.com with the values from your environment.

```
git clone -b refactoring https://github.com/onzack/rancher-saas-chart.git
cat << EOF >> custom-values.yaml
# Infrastructure environemnt specific values for Rancher SaaS.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
 
rancher:
  tag: v2.5.6
  twoPointFive: true
 
rancherGuard:
  enabled: false
  
storage:
  enabled: false
 
ingress:
  letsEncrypt:
    enabled: false
EOF
helm upgrade --install -n rancher-dev1 \
  -f ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas/size-S.yaml \
  -f custom-values.yaml \
  --set rancher.size=S \
  --set ingress.TLSkey="TLS Key base64 encoded" \
  --set ingress.TLScert="TLS Cert base64 encoded" \
  --set ingress.CAcert="TLS CA cert base64 encoded" \
  --set rancher.instanceName=rancher-dev1 \
  --set ingress.domain="rancher.example.com" \
  rancher-dev1 ./rancher-saas-chart/deployments/kubernetes/helm/rancher-saas
```
To access your new Rancher instance go to https://rancher-dev1.rancher.example.com.   

More documentation will follow.

# Licence
Copyright 2021 ONZACK AG

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
