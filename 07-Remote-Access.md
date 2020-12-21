# Configuring kubectl for Remote Access

Run in master node, $HOME directory, also embed all the certificates in the config file, in case we move the temporary directory pki and easier if we want to download the configuration file.

## Prepare Configuration File

```shell
KUBERNETES_PUBLIC_ADDRESS=192.168.1.164
```

```shell
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=pki/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
    --client-certificate=pki/admin.pem \
    --client-key=pki/admin-key.pem \
    --embed-certs=true

kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

kubectl config use-context kubernetes-the-hard-way
```

The result is stored in `~/.kube/config` file, download the config file.

```shell
scp pi@rpi-k8s-master.local:~/.kube/config /home/abel/.kube/
```

## Verification from Remote Computer

```shell
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.4", GitCommit:"d360454c9bcd1634cf4cc52d1867af5491dc9c5f", GitTreeState:"clean", BuildDate:"2020-11-11T13:17:17Z", GoVersion:"go1.15.2", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18+", GitVersion:"v1.18.13-rc.0.15+6d211539692cee", GitCommit:"6d211539692cee9ca82d8e1a6831f7e51e66558d", GitTreeState:"clean", BuildDate:"2020-11-23T19:28:31Z", GoVersion:"go1.15.5", Compiler:"gc", Platform:"linux/arm"}
```

```shell
$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
```

```shell
$ kubectl get nodes
NAME   STATUS   ROLES    AGE    VERSION
p1     Ready    <none>   36h    v1.18.13-rc.0.15+6d211539692cee-dirty
p2     Ready    <none>   114m   v1.18.13-rc.0.15+6d211539692cee-dirty
```

```shell
$ kubectl get --raw='/readyz?verbose'
[+]ping ok
[+]log ok
[+]etcd ok
[+]poststarthook/start-kube-apiserver-admission-initializer ok
[+]poststarthook/generic-apiserver-start-informers ok
[+]poststarthook/start-apiextensions-informers ok
[+]poststarthook/start-apiextensions-controllers ok
[+]poststarthook/crd-informer-synced ok
[+]poststarthook/bootstrap-controller ok
[+]poststarthook/rbac/bootstrap-roles ok
[+]poststarthook/scheduling/bootstrap-system-priority-classes ok
[+]poststarthook/apiserver/bootstrap-system-flowcontrol-configuration ok
[+]poststarthook/start-cluster-authentication-info-controller ok
[+]poststarthook/start-kube-aggregator-informers ok
[+]poststarthook/apiservice-registration-controller ok
[+]poststarthook/apiservice-status-available-controller ok
[+]poststarthook/kube-apiserver-autoregistration ok
[+]autoregister-completion ok
[+]poststarthook/apiservice-openapi-controller ok
[+]shutdown ok
healthz check passed
```

## Test Pod Creation

From the remote computer or master node. 

```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: arm32v5/nginx:1.18
    ports:
    - containerPort: 80
EOF
```

```shell
kubectl get pods -o wide -w
NAME        READY   STATUS              RESTARTS   AGE   IP       NODE   
nginx-pod   0/1     ContainerCreating   0          8s    <none>   p1     
nginx-pod   1/1     Running             0          23s   10.200.0.54   p1
```

Some output omitted for brevity. The important thing are that it was scheduled for Node `p1` and the pod IP is `10.200.0.54`. On node `p1` run:

```shell
pi@p1:~ $ curl http://10.200.0.54/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
...
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and working. Further configuration is required.</p>
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

Success !
