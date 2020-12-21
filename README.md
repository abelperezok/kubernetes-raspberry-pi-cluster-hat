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

- [Introduction - Setting Up the Cluster](00-Intro.md)
- [Part 1 - Provision PKI Infrastructure](01-PKI.md)
- [Part 2 - Build Binaries From Source Code](02-Build-Binaries.md)
- [Part 3 - Prepare Configuration Files](03-Prepare-Config.md)
- [Part 4 - Bootstrapping the Etcd Cluster](04-Etcd.md)
- [Part 5 - Bootstrapping the Control Plane](05-Control-Plane.md)
- [Part 6 - Bootstrapping the Worker Nodes](06-Worker-Nodes.md)
- [Part 7 - Configuring for Remote Access](07-Remote-Access.md)