# Provision PKI infrastructure

This step is pretty much the same as the original guide except for a few tweaks:

* Internal and external IPs are different from the proposed computing resources.
* Hostnames are different from the proposed scheme.
* Only one master node in this setup, therefore only one IP to look after for etcd.
* I've updated the TLS fields to my location in Manchester, England.

All commands will be run in `~/pki` directory.

## Certificate Authority

```shell
cat > ca-config.json <<EOF
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
cat > ca-csr.json <<EOF
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
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

## The Admin Client Certificate

```shell
cat > admin-csr.json <<EOF
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
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
```

## The Kubelet Client Certificates

One client certificate for each worker node.

```shell
for instance in 1 2; do
cat > p${instance}-csr.json <<EOF
{
  "CN": "system:node:p${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF

INTERNAL_IP=172.19.181.${instance}

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=p${instance},${INTERNAL_IP} \
  -profile=kubernetes \
  p${instance}-csr.json | cfssljson -bare p${instance}
done
```

## The Controller Manager Client Certificate

```shell
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
```

## The Kube Proxy Client Certificate

```shell
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
```

## The Scheduler Client Certificate

```shell
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```

## The Kubernetes API Server Certificate

Don't forget to include the IP `10.32.0.1` as it's used by the ClusterIP service and CoreDNS will connect to it. I discovered this the hard way.

```
KUBERNETES_PUBLIC_ADDRESS=192.168.1.164
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
```

```shell
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Manchester",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,172.19.181.254,rpi-k8s-master,rpi-k8s-master.local,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

## The Service Account Key Pair

```shell
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "GB",
      "L": "Portland",
      "O": "Manchester",
      "OU": "Kubernetes The Hard Way",
      "ST": "England"
    }
  ]
}
EOF
```

```shell
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
```

## Distribute the Files

```shell
for instance in p1 p2; do
  ssh ${instance} "mkdir certs"
  scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/certs/
done

cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem ../certs/
```
