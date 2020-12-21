# Deploying the DNS Cluster Add-on

Up to this point the cluster is fully functional except for the DNS resolution inside the pods, i.e accessing services exposed inside the cluster by pods. It also applies to DNS resolution to external hosts.

## Deploy CoreDNS 

This yaml file contains the deployment of [CoreDNS](https://coredns.io/) along with some other kubernetes objects to connect with the cluster, such as `Role`, `RoleBinding`, `ConfigMap`.

```shell
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.7.0.yaml
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.apps/coredns created
service/kube-dns created
```

Wait a few seconds and the get the coredns pods

```shell
kubectl get pods -l k8s-app=kube-dns -n kube-system
NAME                       READY   STATUS    RESTARTS   AGE
coredns-5677dc4cdb-l7qhl   1/1     Running   0          55s
coredns-5677dc4cdb-tmnnr   1/1     Running   0          55s
```

Edit the configuration map to include the forwarding to our external DNS.

```shell
kubectl edit -n kube-system configmaps coredns
```

In this case my home router has the IP address `192.168.1.254`. Add the following line after the `kubernetes` block.

`forward . 192.168.1.254`

Optionally you can also add `log` to help in troubleshooting.

It should read 

```
...
Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        cache 30
        loop
        reload
        loadbalance
        log
        forward . 192.168.1.254
    }
...
```

## Verification 

The original guide suggests to use `busybox` image, however I found many issues when trying it for the DNS resolution tests. Instead, I used a plain `Debian` and installed `dnsutils` package on it to achieve the same results.

### Prepare the Test Pod

```shell
kubectl run debian --image=arm32v5/debian --command -- sleep 7200
pod/debian created
```

```shell
kubectl get pods -l run=debian -w
NAME     READY   STATUS              RESTARTS   AGE
debian   0/1     ContainerCreating   0          116s
debian   1/1     Running             0          3m10s
```

If this step works, it proves we have external hosts resolution working.

```shell
kubectl exec debian -- apt update
kubectl exec debian -- apt install -y dnsutils
```

### Test Resolving `kubernetes` 

```shell
kubectl exec debian -- nslookup kubernetes
Server:	10.32.0.10
Address:	10.32.0.10#53

Name:	kubernetes.default.svc.cluster.local
Address: 10.32.0.1
```

### Test Resolving `nginx` Pod

```shell
kubectl create deployment nginx --image=arm32v5/nginx
deployment.apps/nginx created
```

```shell
kubectl get pods -l app=nginx -w
NAME                     READY   STATUS              RESTARTS   AGE
nginx-54cb54645d-88k7c   0/1     ContainerCreating   0          53s
nginx-54cb54645d-88k7c   1/1     Running             0          76s
```

Resolve nginx pod using short name `nginx`

```shell
kubectl exec debian -- nslookup nginx
Server:		10.32.0.10
Address:	10.32.0.10#53

Name:	nginx.default.svc.cluster.local
Address: 10.32.0.110
```

Resolve nginx pod using long name `nginx.default.svc.cluster.local`

```shell
kubectl exec debian -- nslookup nginx.default.svc.cluster.local
Server:		10.32.0.10
Address:	10.32.0.10#53

Name:	nginx.default.svc.cluster.local
Address: 10.32.0.110
```
