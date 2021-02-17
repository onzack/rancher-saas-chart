# ONZACK Rancher Software as a Service Helm Chart
This repository contains the Helm Chart for ONZACK Rancher Software as a Service.  
The Helm Chart is designed as a Rancher Chart for better use experience together with Rancher.  
[See official Rancher documentation](https://rancher.com/docs/rancher/v2.x/en/helm-charts/legacy-catalogs/creating-apps/)

# Installation
### Prepare
1. Create a Namespace:
```
kubectl create namespace <namespace>
```
2. Create secret containing credentials for InfluxDB, if you plan to use Rancher-Guard as monitoring tool:
```
kubectl -n <namespace> create secret generic rancher-guard-secret --from-literal=influxDBUser=<some user> --from-literal=influxDBPW='<some password>'
```
3. Create secret containing the custom CA certificate, matching the ingress TLS certificate, if you don't use the Let's Encrypt option:
```
kubectl -n <namespace> create secret tls custom-internal-ca --cert=<path/to/cert/file>
```

### Install
1. Clone this repository:
```
git clone https://github.com/onzack/rancher-saas-chart.git
```
2. Adjust values.yaml file:
```
cp ./deployments/kubernetes/helm/values.yaml ./custom-values.yaml
vim ./custom-values.yaml
```
3. Install Helm Chart:
```
helm install -f custom-values.yaml -f size-[S|M|L].yaml -n <namespace> <instalnceName> ./deployments/kubernetes/helm
```

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
