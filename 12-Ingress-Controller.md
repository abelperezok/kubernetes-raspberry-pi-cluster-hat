# Install Nginx Ingress Controller

A fully functional Kubenetes cluster should be able to allow external traffic into the cluster to interact with the deployed applications. 

At this point, an Ingress Controller is needed, Nginx Ingress Controller is a very popular option for bare-metal installations like this one. 

Documentation can be found at these locations: 
* https://docs.nginx.com/nginx-ingress-controller/installation/building-ingress-controller-image/
* https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-manifests/

Specific for bare metal
* https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/baremetal.md

## Build the Ingress Controller from Source Code

Clone source code repository is https://github.com/nginxinc/kubernetes-ingress

```shell
git clone https://github.com/nginxinc/kubernetes-ingress/
cd kubernetes-ingress/
git checkout v1.9.1
```

Edit `build/Dockerfile` to adapt for `ARMv6` build

Use different golang image to build `ARG GOLANG_CONTAINER=arm32v5/golang:1.15.5-buster`

Use a different nginx image a base `FROM arm32v5/nginx:1.19.6 AS base`

Add environment variable for cross-compiling 

```
ENV GOOS=linux
ENV GOARCH=arm
ENV GOARM=6
```

Full content of Dockerfile
```
# ARG GOLANG_CONTAINER=golang:latest
ARG GOLANG_CONTAINER=arm32v5/golang:1.15.5-buster

# FROM nginx:1.19.6 AS base
FROM arm32v5/nginx:1.19.6 AS base

# forward nginx access and error logs to stdout and stderr of the ingress
# controller process
RUN ln -sf /proc/1/fd/1 /var/log/nginx/access.log \
	&& ln -sf /proc/1/fd/1 /var/log/nginx/stream-access.log \
	&& ln -sf /proc/1/fd/2 /var/log/nginx/error.log

RUN mkdir -p /var/lib/nginx \
	&& mkdir -p /etc/nginx/secrets \
	&& mkdir -p /etc/nginx/stream-conf.d \
	&& apt-get update \
	&& apt-get install -y libcap2-bin \
	&& setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
	&& setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx-debug \
	&& chown -R nginx:0 /etc/nginx \
	&& chown -R nginx:0 /var/cache/nginx \
	&& chown -R nginx:0 /var/lib/nginx \
	&& apt-get remove --purge -y libcap2-bin \
	&& rm /etc/nginx/conf.d/* \
	&& rm -rf /var/lib/apt/lists/*

COPY internal/configs/version1/nginx.ingress.tmpl \
	internal/configs/version1/nginx.tmpl \
	internal/configs/version2/nginx.virtualserver.tmpl \
	internal/configs/version2/nginx.transportserver.tmpl /

# Uncomment the line below if you would like to add the default.pem to the image
# and use it as a certificate and key for the default server
# ADD default.pem /etc/nginx/secrets/default

USER nginx

ENTRYPOINT ["/nginx-ingress"]


FROM base AS local
COPY nginx-ingress /


FROM $GOLANG_CONTAINER AS builder
ARG VERSION
ARG GIT_COMMIT
WORKDIR /go/src/github.com/nginxinc/kubernetes-ingress/nginx-ingress/cmd/nginx-ingress
COPY . /go/src/github.com/nginxinc/kubernetes-ingress/nginx-ingress/
ENV GOOS=linux
ENV GOARCH=arm
ENV GOARM=6
RUN CGO_ENABLED=0 GOFLAGS='-mod=vendor' \
	go build -installsuffix cgo -ldflags "-w -X main.version=${VERSION} -X main.gitCommit=${GIT_COMMIT}" -o /nginx-ingress


FROM base AS container
COPY --from=builder /nginx-ingress /
```

Build using docker hub repository and image name

make `PREFIX=abelperezok/nginx-ingress-armv6` 

Image is pushed to my personal account `abelperezok` and the tag is the same as the version `1.9.1`

`abelperezok/nginx-ingress-armv6:1.9.1`

## Install Ingress Controller

Following the docs, installing with manifests, before applying the yaml manifests, some tweaks in `daemon-set/nginx-ingress.yaml`. 

* Update image in daemon-set/nginx-ingress.yaml `image: abelperezok/nginx-ingress-armv6:1.9.1`.

* Add hostNetwork to Pod’s spec `hostNetwork: true`.

This is important because in this setup, the worker nodes are in a private network and therefore are inaccessible from the outside, so using the hostNetwork is not a security risk and simplifies the process compared to using a deployment.

```shell
cd deployments/
```

As per docs, apply all the manifests
```shell
kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f rbac/rbac.yaml
kubectl apply -f common/default-server-secret.yaml 
kubectl apply -f common/nginx-config.yaml 
kubectl apply -f common/ingress-class.yaml 
# Not sure if the following resources are required 
kubectl apply -f common/vs-definition.yaml 
kubectl apply -f common/vsr-definition.yaml 
kubectl apply -f common/ts-definition.yaml 
kubectl apply -f common/policy-definition.yaml 
kubectl apply -f common/gc-definition.yaml 
kubectl apply -f common/global-configuration.yaml 
```

Apply daemonset manifest.
```shell
$ kubectl apply -f daemon-set/nginx-ingress.yaml 
daemonset.apps/nginx-ingress created
```

## Verify nginx-ingress is running 

```shell
$ kubectl get pods -n nginx-ingress
NAME                  READY   STATUS    RESTARTS   AGE
nginx-ingress-84xql   1/1     Running   0          17s
nginx-ingress-pj2lc   1/1     Running   0          17s
```

Create an Ingress resource to test the ingress controller is working. Add this to a file named `ingress.yaml`.

```shell
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: virtual-host-ingress
  namespace: default
spec:
  rules:
  - host: blue.example.com
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: 80
        path: /
        pathType: ImplementationSpecific
```

Apply ingress manifest.
```shell
kubectl apply -f ingress.yaml
```

On master node

```shell
pi@rpi-k8s-master:~ $ curl -H "Host: blue.example.com" 172.19.181.1
pi@rpi-k8s-master:~ $ curl -H "Host: blue.example.com" 172.19.181.2
```

The ingress controller works ! 

However, the worker nodes live in a `private network` which is no benefit to access any service deployed. An `external IP` is required to access from outside. In this setup the only `external IP` that can access the private networks is the master node.

## Install Haproxy on the Master Node

One of the solutions to mitigate the issue of accessing the workers nodes in a private network is to use an external proxy such as `haproxy`.

Install haproxy package 
```shell
sudo apt install haproxy
```

Update configuration 
```shell
sudo vi /etc/haproxy/haproxy.cfg
```

Add this to the end of the file

```shell
frontend http_front
   bind *:80
   stats uri /haproxy?stats
   default_backend http_back

backend http_back
  balance roundrobin
  server p1 172.19.181.1:80 check
  server p2 172.19.181.2:80 check

frontend https_front
    bind *:443
    option tcplog
    mode tcp
    default_backend https_back

backend https_back
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server p1 172.19.181.1:443 check
    server p2 172.19.181.2:443 check
```

Restart haproxy service 
```shell
sudo systemctl restart haproxy.service
```

From remote computer 
```shell
$ curl -H "Host: blue.example.com" 192.168.1.164

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

