# Introduction - Setting up the cluster
This is the second attempt after some time when I first tried to set up such a cluster and I started learning [Kubernetes](https://kubernetes.io/). One of the reasons I wanted to do this is because I have two [Raspberry Pi Zero](https://www.raspberrypi.org/products/raspberry-pi-zero/) (and [Zero W](https://www.raspberrypi.org/products/raspberry-pi-zero-w/)) lying around and a new (at the time) [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/). After experimenting for a bit with them individually, I decided to put them to work together. 

Some research brought my attention to [ClusterHAT](https://clusterhat.com/) which simplified all the messing around with USB gadgets to make the Pi Zeros believe they’re connected to a network using USB. Having tested it for a while, I decided to give it a go and install a Kubernetes cluster. 
## Hardware

The specific hardware I used for this exercise is:

* Raspberry Pi 3
* Raspberry Pi Zero
* Raspberry Pi Zero W
* Cluster HAT v2.3
* 3 x micro SD cards (16 GB for master and 8 GB for workers)

For instruction on how to set up the hardware, see [their website](https://clusterctrl.com/setup-assembly).

## Operating System

Download the images for each Pi: controller CNAT and each pi (p1 .. p4) in this case I only used p1 and p2 as I only have two pi zeros. As of this writing, these are the files available to download from [clusterctrl downloads](https://clusterctrl.com/setup-software) I chose the lite version (no Desktop or GUI) and CNAT to use the internal NAT network.

* [Controller] 2020-08-20-8-ClusterCTRL-armhf-lite-CNAT.img
* [Worker 1] 2020-08-20-8-ClusterCTRL-armhf-lite-p1.img
* [Worker 2] 2020-08-20-8-ClusterCTRL-armhf-lite-p2.img



## Preparing the Controller

If you're using Wi-Fi, it needs setting up before booting to make it easy to connect totally headless.

### Set up wifi on the controller 

Mount the microSD card and in /boot partition modify the file `/boot/wpa_supplicant.conf`

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=GB

network={
 ssid="XYZ"
 psk="abcdef.zyx.1234"
}
```

Create an empty file to allow SSH service to start with the system.

```shell
touch /boot/ssh
```


### Understand the networking model


Host name      |   External IP |    Internal IP | Role   |
---------------|---------------|----------------|--------|
rpi-k8s-master | 192.168.1.164 | 172.19.181.254 | master |
p1             |      NAT      | 172.19.181.1   | worker |
p2             |      NAT      | 172.19.181.2   | worker |



Diagram 

### Upgrade the system

It's always a good start with a fresh up to date system. Something particular of Raspbian is that you should use `full-upgrade` instead of just `upgrade` as it could be the case that it doesn't download all the dependencies of the new packages, kind of weird. 

```shell
$ sudo apt update
$ sudo apt full-upgrade
```

### Change the hostname 

In my case, I wanted to identify the master node from the rest, I updated to `rpi-k8s-master` 

```shell
$ sudo hostnamectl set-hostname rpi-k8s-master
```

### Set up and verify connectivity 

Once all the base hardware is up and running, it'll be much easier if ssh config file is configured to connect to the pi zeros.

Create a config file if it's not already there.

```shell
vi ~/.ssh/config
```

```
Host *
  ServerAliveInterval 180
  ServerAliveCountMax 2
  IdentitiesOnly=yes
  IdentityFile ~/.ssh/local_rsa

Host p1
    Hostname 172.19.181.1
    User pi
Host p2
    Hostname 172.19.181.2
    User pi
```

Add the pi zeros IPs to the local hosts file.

```shell
$ cat | sudo tee -a /etc/hosts << HERE
172.19.181.1    p1
172.19.181.2    p2
HERE
```

### Generate ssh keys and copy to the pi zeros

```shell
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/local_rsa -C "local key ClusterHAT"

ssh-copy-id -i .ssh/local_rsa.pub p1

ssh-copy-id -i .ssh/local_rsa.pub p2
```
### Install the Client Tools

The Client Tools (on the Pi 3) this can be installed optionally on your local environment as well. 

Get the CloudFlare SSL tools

```shell
sudo apt install golang-cfssl
```

Verify it’s working 
```shell
$ cfssl version
Version: 1.2.0
Revision: dev
Runtime: go1.8.3
```

Install tmux

```shell
sudo apt install tmux
```