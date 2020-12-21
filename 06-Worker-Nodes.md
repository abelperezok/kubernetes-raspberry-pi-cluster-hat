# Bootstrapping the Kubernetes Worker Nodes

All the commands need to be run on each of the worker nodes (`p1` and `p2` in this case)

## Prerequisites

Install `socat`, `conntrack` and `ipset`

```shell
sudo apt-get update
sudo apt-get -y install socat conntrack ipset
```

Enable `systemd-resolved` for DNS.

```shell
sudo systemctl enable systemd-resolved.service
sudo systemctl start systemd-resolved.service
```

Disable Swap

As per [this guide](https://www.paulcourt.co.uk/article/pi-swap), there are few commands to run in order to disable the swap permanently.

```shell
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo update-rc.d dphys-swapfile remove
sudo rm -f /etc/init.d/dphys-swapfile

sudo service dphys-swapfile stop
sudo systemctl disable dphys-swapfile.service
```

Enable `br_netfilter` kernel module. This is used by `kube-proxy`.

```shell
echo br_netfilter | sudo tee -a /etc/modules
```

After these steps `reboot` the node.

## Install the worker binaries

```shell
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

sudo mv bin/containerd* bin/ctr /bin/
sudo mv bin/crictl bin/kube* bin/runc bin/recvtty /usr/local/bin/
sudo mv bin/* /opt/cni/bin/
```

## Configure CNI Networking

Pod CIDR is `10.200.${i}.0/24` where `${i}` is the sequence of the worker node. In this case, for the Pi 1 is `10.200.0.0/24` and for the Pi 2 is `10.200.1.0/24`. Choose accordingly one of the following for the appropriated worker node.

```shell
POD_CIDR=10.200.0.0/24
POD_CIDR=10.200.1.0/24
```

```shell
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

```shell
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
```

## Configure containerd

Important attention to `titilambert/armv6-pause:latest`, the original `k8s.gcr.io/pause` doesn’t work on ARMv6, so I found an alternative already published that worked for me. You can always build the image yourself from the source once compiled the `pause` binary but I didn’t go that far.

```shell
sudo mkdir -p /etc/containerd/
```

```shell
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri]
    sandbox_image = "docker.io/titilambert/armv6-pause:latest"
    [plugins.cri.containerd]
      snapshotter = "overlayfs"
      [plugins.cri.containerd.default_runtime]
        runtime_type = "io.containerd.runtime.v1.linux"
        runtime_engine = "/usr/local/bin/runc"
        runtime_root = ""
EOF
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

This is more for troubleshooting, but it's handy to have it already configured in case it's needed.
```shell
cat << EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 3
debug: true
pull-image-on-create: false
EOF
```

## Configure the Kubelet

```shell
sudo mv certs/${HOSTNAME}-key.pem certs/${HOSTNAME}.pem /var/lib/kubelet/
sudo mv config/${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv certs/ca.pem /var/lib/kubernetes/
```

```shell
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Configure the Kubernetes Proxy

```shell
sudo mv config/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

```shell
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml \\
  --masquerade-all
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Enable and start services

```shell
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
```

## Test worker nodes

On the worker nodes, test `containerd` is up and running using `crictl tool`.

```shell
sudo crictl info
```

On the master node, $HOME directory, run:

```shell
$ kubectl get nodes --kubeconfig config/admin.kubeconfig
NAME   STATUS   ROLES    AGE   VERSION                                                                           
p1     Ready    <none>   34h   v1.18.13-rc.0.15+6d211539692cee-dirty
p2     Ready    <none>   12m   v1.18.13-rc.0.15+6d211539692cee-dirty
```

The trailing `-dirty` is because I didn’t commit my changes to the kubelet source above, therefore the build script picked up on it and updated the version id.
