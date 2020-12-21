# Bootstrapping the Etcd Cluster

In this case there is only one controller node, not really an etcd cluster. 

## Install Etcd and Etcdctl

Inside master node at $HOME directory. 

```shell
sudo mv bin/etcd* /usr/local/bin/
```

Prepare etcd directory

```shell
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
```

Copy the certificates
```shell
sudo cp certs/ca.pem certs/kubernetes*.pem /etc/etcd/
```

```shell
ETCD_NAME=$(hostname -s)
INTERNAL_IP=172.19.181.254
```

```shell
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --client-cert-auth \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --data-dir=/var/lib/etcd \\
  --logger=zap
Restart=on-failure
RestartSec=5
Environment=ETCD_UNSUPPORTED_ARCH=arm

[Install]
WantedBy=multi-user.target
EOF
```

```shell
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

## Verify It’s Working

```shell
sudo etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

Output
```
8e9e05c52164694d, started, rpi-k8s-master, http://localhost:2380, https://172.19.181.254:2379, false  
```