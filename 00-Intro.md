## Introduction
This is the second attempt after some time when I first tried to set up such a cluster and I started learning [Kubernetes](https://kubernetes.io/). One of the reasons I wanted to do this is because I have two Raspberry Pi Zero (and Zero W) lying around and a new (at the time) Raspberry Pi 3. After experimenting for a bit with them individually, I decided to put them to work together. 

Some research brought my attention to [ClusterHAT](https://clusterhat.com/) which simplified all the messing around with USB gadgets to make the Pi Zeros believe they’re connected to a network using USB. Having tested it for a while, I decided to give it a go and install a Kubernetes cluster. 
### Hardware

The specific hardware I used for this exercise is:

* Raspberry Pi 3
* Raspberry Pi Zero
* Raspberry Pi Zero W
* Cluster HAT v2.3
* 3 x micro SD cards (16 GB for master and 8 GB for workers)

For instruction on how to set up the hardware, see [their website](https://clusterctrl.com/setup-assembly).

### Software

Download the images for each Pi: controller CNAT and each pi (p1 .. p4) in this case I only used p1 and p2 as I only have two pi zeros. As of this writing, these are the files available to download from [clusterctrl downloads](https://clusterctrl.com/setup-software) I chose the lite version (no Desktop or GUI) and CNAT to use the internal NAT network.

* 2020-08-20-8-ClusterCTRL-armhf-lite-CNAT.img
* 2020-08-20-8-ClusterCTRL-armhf-lite-p2.img
* 2020-08-20-8-ClusterCTRL-armhf-lite-p1.img

