# KUBE-GUARD
KUBE-GUARD is a project for simple and most basic Kubernetes Monitoring.  
The Docker Image contains the webhook and kubectl software package, a webhook definition and a bash scrpt, that uses kubectl to gather health information from the Kubernetes Master API.  
Calling the webhook URL triggers the bash scripts and returns the health state of a Kubernetes component.

KUBE-GUARD supports these modes
* health
* metrics
* logs
* connectivity

Besides the three modes, kube-guard also offers a webhook for Kubernetes readiness probe of kube-guard

# Usage
## Start the Docker Container locally
### kube-guard in health mode

```
sudo docker run -tid \
    -p 9000:9000 \
    -e TZ=Europe/Zurich \
    -e KUBE_APISERVERS_COUNT=2 \
    -v /home/domenic/.kube/config:/home/kube-guard/.kube/config \
    --name kube-guard \
    dmlabs/kube-guard:0.4 -hooks=/etc/webhooks/readiness.json -hooks=/etc/webhooks/health.json 

```

### kube-guard in metrics mode

```
sudo docker run -tid \
    -p 9000:9000 \
    -e TZ=Europe/Zurich \
    -v /home/domenic/.kube/config:/home/kube-guard/.kube/config \
    --name kube-guard \
    dmlabs/kube-guard:0.4 -hooks=/etc/webhooks/readiness.json -hooks=/etc/webhooks/metrics.json

```

### kube-guard in logs mode

```
sudo docker run -tid \
    -p 9000:9000 \
    -e TZ=Europe/Zurich \
    -e KUBE_APISERVERS_COUNT=2 \
    -v /home/domenic/.kube/config:/home/kube-guard/.kube/config \
    --name kube-guard \
    dmlabs/kube-guard:0.4 -hooks=/etc/webhooks/readiness.json -hooks=/etc/webhooks/logs.json

```

### kube-guard in connectivity mode

```
sudo docker run -tid \
    -p 9000:9000 \
    -e TZ=Europe/Zurich \
    -e CLUSTERNAME="dmlabs-apps-prod" \
    -v /home/domenic/.kube/config:/home/kube-guard/.kube/config \
    --name kube-guard \
    dmlabs/kube-guard:0.4 -hooks=/etc/webhooks/readiness.json -hooks=/etc/webhooks/connectivity.json

```

### kube-guard wiht all modes

```
sudo docker run -tid \
    -p 9000:9000 \
    -e TZ=Europe/Zurich \
    -e KUBE_APISERVERS_COUNT=2 \
    -e CLUSTERNAME="dmlabs-apps-prod" \
    -v /home/domenic/.kube/config:/home/kube-guard/.kube/config \
    --name kube-guard \
    dmlabs/kube-guard:0.4 -verbose -hooks=/etc/webhooks/readiness.json -hooks=/etc/webhooks/healht.json -hooks=/etc/webhooks/metrics.json -hooks=/etc/webhooks/logs.json -hooks=/etc/webhooks/connectivity.json

```
With the option -vervose this will generate a lot of logs.  
Maybe it's a good idea to run kube-guard in log mode separately.

## Call the Webhook URL
### For health

```
curl localhost:9000/hooks/health -d "component=etcd"

```
or
```
curl -k -H "Content-Type: application/json" localhost:9000/hooks/health -d '{"component":"etcd"}'

```

Payload options:
* nothing -> Dispaly what components are allowd as payload. Is not suited for Kubernetes liveness and readyness probes.
* -d "component=etcd" -> check etcd health (etcd-0, etcd-1, etcd-2)
* -d "component=scheduler" -> check scheduler health
* -d "component=controller-manager" -> check controller-manager health
* -d "component=nodes" -> check all nodes
* -d "component=kube-apiserver" -> check if all kube-apiservers are available

#### Expected return
If everything is fine:

```
True

```
If case of an error or problems:

```
False

```

### For metrics

```
curl localhost:9000/hooks/metrics

```
#### Expected return

```
# HELP kubernets_kubeapisever_health histogram
# TYPE kubernets_kubeapiserver_health histogram
kubernets_kubeapiserver_health: 1
# HELP kubernets_controllermanager_health histogram
# TYPE kubernets_controllermanager_health histogram
kubernets_controllermanager_health: 1
# HELP kubernets_scheduler_health histogram
# TYPE kubernets_scheduler_health histogram
kubernets_scheduler_health: 1
[...]

```

### For logs

```
curl localhost:9000/hooks/logs

```

#### Expected return
If everything is fine the webhooks does not return anything.  
If case of an error or problems the webhooks will return an error message.

### For connectivity

```
curl localhost:9000/hooks/connectivity

```
#### Expected return
The value of the environment variable CLUSTERNAME:

```
dmlabs-apps-prod

```

### For liveness probe

```
curl localhost:9000/hooks/readiness

```
#### Expected return
The message: "Readiness proble successful."

# Official Docs
### Webhook
https://github.com/adnanh/webhook