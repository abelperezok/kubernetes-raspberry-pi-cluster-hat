# How to install Kubernetes from scratch using Raspberry Pi and ClusterHAT 

This is a learning exercise on how to install Kubernetes from scratch on Raspberry Pi 3 (master) and Zeros (workers). 

In this guide I'll walk you through the famous guide [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) created by [Kelsey Hightower](https://github.com/kelseyhightower) I like to call this guide: the very very hard way. 

<img src="img/rasbperrypi-clusterhat.jpg" width="720">

The final result should look like this:

<img src="img/kubernetes-running.png" width="720">

## Prerequisites

* Basic understanding on Linux command line (Debian/Raspbian is recommended)
* Basic knowledge of Linux networking (general networking)
* Basic understanding on containers (no docker is required)
* Local Wi-fi or a free Ethernet port connection 
* Lots of patience - you'll need it! 

## Content

- [Introduction](00-Intro.md)
- [Provision PKI Infrastructure](01-PKI.md)
- [Build The Binaries](02-Build-Binaries.md)
- [Prepare Configuration Files](03-Prepare-Config.md)