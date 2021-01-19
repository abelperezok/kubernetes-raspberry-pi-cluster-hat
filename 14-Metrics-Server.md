# Metrics Server

In this section we’ll install the metrics server so we can monitor the resource utilisation of the cluster. It requires some changes to the previous installation of the kube-api server as it needs to allow extensions to connect and authenticate. 

## Prepare Kube-API server

We need to create another CA for extensions, in this case I named it ca-ext.

### The Extension Certificate Authority

```shell
cat > ca-ext-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

```shell
cat > ca-ext-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "England"
    }
  ]
}
EOF
```
```shell
cfssl gencert -initca ca-ext-csr.json | cfssljson -bare ca-ext
```

### The Extension Client Certificate

```shell
cat > ext-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca-ext.pem \
  -ca-key=ca-ext-key.pem \
  -config=ca-ext-config.json \
  -profile=kubernetes \
  ext-csr.json | cfssljson -bare ext
```

All the output files will be copied with the rest of the certificates previously generated. 

```shell
sudo cp ca-ext.pem ca-ext-key.pem ext-key.pem ext.pem /var/lib/kubernetes/
```

Update the kube-apiserver to add more flags to the entry point.

```shell
sudo vi /etc/systemd/system/kube-apiserver.service
```

Add these flags at the end of the existing ones. Mind the \ in the existing last flag.

```
--enable-aggregator-routing=true \
--requestheader-client-ca-file=/var/lib/kubernetes/ca-ext.pem \
--requestheader-extra-headers-prefix=X-Remote-Extra- \
--requestheader-group-headers=X-Remote-Group \
--requestheader-username-headers=X-Remote-User \
--proxy-client-cert-file=/var/lib/kubernetes/ext.pem \
--proxy-client-key-file=/var/lib/kubernetes/ext-key.pem
```

```shell
sudo systemctl daemon-reload
sudo systemctl start kube-apiserver.service
```
 
## Build the metrics-server

Source code https://github.com/kubernetes-sigs/metrics-server

```shell
git clone https://github.com/kubernetes-sigs/metrics-server
cd metrics-server/
git checkout v0.4.1
```

```shell
docker run --rm -it -v "$PWD":/usr/src/myapp -w /usr/src/myapp arm32v5/golang:1.15.5-buster bash

root@f190a06a91c3:/usr/src/myapp# make ARCH=arm
```

It produces `./metrics-server` executable

I extracted the last block from the original Dockerfile and replaced the FROM image and the --from as there is only one stage in this new `Dockerfile.minimal`.

```
FROM arm32v5/golang:1.15.5-buster
COPY metrics-server /
USER 65534
ENTRYPOINT ["/metrics-server"]
```

```shell
docker build -t abelperezok/metrics-server-armv6:0.4.1 -f Dockerfile.minimal .

Sending build context to Docker daemon  61.52MB
Step 1/4 : FROM arm32v5/golang:1.15.5-buster
 ---> 56b2e5ac6aa2
Step 2/4 : COPY metrics-server /
 ---> 2f9af7f67783
Step 3/4 : USER 65534
 ---> Running in c4ed7bf9ff92
Removing intermediate container c4ed7bf9ff92
 ---> c99bdde8d29e
Step 4/4 : ENTRYPOINT ["/metrics-server"]
 ---> Running in 479961333d53
Removing intermediate container 479961333d53
 ---> e2f4ea68b082
Successfully built e2f4ea68b082
Successfully tagged abelperezok/metrics-server-armv6:0.4.1
```

```shell
docker login
docker push abelperezok/metrics-server-armv6:0.4.1
```

Download the manifest from https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

curl -o manifests.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -L

Find the `Deployment` object and replace 

The original image `image: k8s.gcr.io/metrics-server/metrics-server:v0.4.1`

With the recently created `image: abelperezok/metrics-server-armv6:0.4.1`

Add hostNetwork to the spec `hostNetwork: true`

Add container hostPort `hostPort: 4443`

Apply the manifest to install metrics-server
```shell
kubectl apply -f manifests.yaml
```

## Verify it's working

```shell
kubectl get pods -n kube-system -o wide -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE   IP             NODE   NOMINATED NODE   READINESS GATES
metrics-server-556fbf5c74-rhkf6   1/1     Running   2          84m   172.19.181.1   p1     <none>           <none>
```

```shell
kubectl top nodes
NAME   CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
p1     392m         39%    244Mi           73%       
p2     336m         33%    227Mi           68%
```

```shell
kubectl top pods 
NAME                     CPU(cores)   MEMORY(bytes)   
nginx-54cb54645d-88k7c   0m           1Mi             
pod-pvc-normal           0m           1Mi             
pod-pvc-volume           0m           1Mi
```

## Useful links
* https://github.com/kubernetes-retired/kube-aws/issues/1355
* https://discourse.linkerd.io/t/error-no-client-ca-cert-available-for-apiextension-server/947
