# Provisioning Pod Network Routes

In two terminals, run two pods using `arm32v5/busybox` and execute a shell in each of them. Run the following commands:

```shell
kubectl run shell1 --rm -it --image arm32v5/busybox -- sh
```
```shell
kubectl run shell2 --rm -it --image arm32v5/busybox -- sh
```

Verify they’re scheduled in two different nodes. If not, create more pods until they are scheduled in two different nodes.

```shell
kubectl get pods -o wide
NAME     READY   STATUS    RESTARTS   AGE   IP            NODE
shell1   1/1     Running   0          14m   10.200.0.59   p1 
shell2   1/1     Running   0          14m   10.200.1.30   p2 
```

## Test without routes

```shell
kubectl run shell1 --rm -it --image arm32v5/busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # hostname -i
10.200.0.59
/ # ping 10.200.1.30
PING 10.200.1.30 (10.200.1.30): 56 data bytes
^C
--- 10.200.1.30 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
```

```shell
kubectl run shell2 --rm -it --image arm32v5/busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # hostname -i
10.200.1.30
/ # ping 10.200.0.59
PING 10.200.0.59 (10.200.0.59): 56 data bytes
^C
--- 10.200.0.59 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
```

## Add the missing routes

On master node, run the following command to add the missing routes.

```shell
sudo route add -net 10.200.0.0 netmask 255.255.255.0 gw 172.19.181.1
sudo route add -net 10.200.1.0 netmask 255.255.255.0 gw 172.19.181.2
```

## Repeat the test with routes in place

```shell
kubectl run shell1 --rm -it --image arm32v5/busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # hostname -i
10.200.0.59
/ # ping 10.200.1.30
PING 10.200.1.30 (10.200.1.30): 56 data bytes
64 bytes from 10.200.1.30: seq=0 ttl=62 time=13.536 ms
64 bytes from 10.200.1.30: seq=0 ttl=62 time=13.536 ms
^C
--- 10.200.1.30 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
```

```shell
kubectl run shell2 --rm -it --image arm32v5/busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # hostname -i
10.200.1.30
/ # ping 10.200.0.59
PING 10.200.0.59 (10.200.0.59): 56 data bytes
64 bytes from 10.200.1.30: seq=0 ttl=62 time=13.536 ms
64 bytes from 10.200.1.30: seq=0 ttl=62 time=13.536 ms
^C
--- 10.200.0.59 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss

```

Now two pods in different nodes can communicate. Success! 