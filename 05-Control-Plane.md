# Bootstrapping the Kubernetes Control Plane

Inside master node at $HOME directory/ 

```shell
sudo mkdir -p /etc/kubernetes/config
```

No need to give execution permission to the binaries, since they were built from source, the compiler already made them executable. 

Prepare directories and config / certificate files.

```shell
sudo mv bin/kube* /usr/local/bin/
```

```shell
sudo mkdir -p /var/lib/kubernetes/
```

```shell
sudo mv certs/* /var/lib/kubernetes/
sudo mv config/encryption-config.yaml /var/lib/kubernetes/
```

## API Server

```shell
INTERNAL_IP=172.19.181.254
KUBERNETES_PUBLIC_ADDRESS=192.168.1.164
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://${INTERNAL_IP}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --external-hostname=${KUBERNETES_PUBLIC_ADDRESS} \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Controller Manager

```shell
sudo mv config/kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Scheduler

```shell
sudo mv config/kube-scheduler.kubeconfig /var/lib/kubernetes/
```

```shell
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Enable and start services

```shell
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

## Verify the installation

The guide recommends to run:

```shell
kubectl get componentstatuses --kubeconfig config/admin.kubeconfig
NAME                 STATUS    MESSAGE             ERROR                           
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health":"true"}
```

However, this might not work in some cases, in [this github issue](https://github.com/kubernetes/kubernetes/issues/93472), they recommend not to use that any more, as it’s deprecated, you might get a message looks like this:

```shell
NAME                 STATUS      MESSAGE                              ERROR
controller-manager   Healthy     ok                                                                                            
etcd-0               Healthy     {"health":"true"}
scheduler            Unhealthy   Get "http://127.0.0.1:10251/healthz": dial
                                 tcp 127.0.0.1:10251: connect: connection
                                 refused
```

Also, as per [kubernetes documentation](https://kubernetes.io/docs/reference/using-api/health-checks/), they recommend to run instead `/readyz?verbose`. 

```shell
$ curl -k https://localhost:6443/readyz?verbose
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

## RBAC for Kubelet Authorization

Inside master node at $HOME directory. Create ClusterRole and ClusterRoleBinding.

```shell
cat <<EOF | kubectl apply --kubeconfig config/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

```shell
cat <<EOF | kubectl apply --kubeconfig config/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## Test the Control Plane

Since there is only one master node, there is no need for an external load balancer. In that case, we already have the public IP, test the `/version` endpoint from outside the cluster.

Download the certificate if we don’t have it already in our local computer.

```shell
$ scp pi@rpi-k8s-master.local:/home/pi/certs/ca.pem .
```

Test the curl command using the certificate.

```shell
$ KUBERNETES_PUBLIC_ADDRESS=192.168.1.164
$ curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
{
  "major": "1",
  "minor": "18+",
  "gitVersion": "v1.18.13-rc.0.15+6d211539692cee",
  "gitCommit": "6d211539692cee9ca82d8e1a6831f7e51e66558d",
  "gitTreeState": "clean",
  "buildDate": "2020-11-23T19:28:31Z",
  "goVersion": "go1.15.5",
  "compiler": "gc",
  "platform": "linux/arm"
}
```

Success!

## Transfer the binaries to the worker nodes

```shell
for instance in p1 p2; do
  scp /usr/local/bin/kubectl ${instance}:~/bin/
  scp plugins/* ${instance}:~/bin/
  scp bin/* ${instance}:~/bin/  
done
```
