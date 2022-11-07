#!/bin/bash
######################################################
# Tutorial Author: Abel Perez Martinez
# Tutorial: https://github.com/abelperezok/kubernetes-raspberry-pi-cluster-hat
# Script Author: Bryan McWhirt
# Description: 
#   This is a bash script that automates the
#   creation of the PKI. Make sure you understand
#   what is being done or you will run into issues.
#   I wrote this as it was tedious to do every time 
#   I started over to experiment.
# 
# Usage:
#   Fill in your information for:
#       COUNTRY, STATE_PROV, LOCALITY, ORG, ORG_UNIT,
#       KUBERNETES_PUBLIC_ADDRESS
#   Verify you INTERNAL_IP_BASE matches the one here.
#   Abel's documentation uses 172.19.181. but mine 
#   was 172.19.180.
#
# Copy this file and ca-config.json to ~/ on the 
#   orchistrator node.
#
# chmod 740 ~/pki.sh
#
# cd ~
#
# ./pki.sh
######################################################
declare -x COUNTRY=""
declare -x STATE_PROV=""
declare -x LOCALITY=""
declare -x ORG=""
declare -x ORG_UNIT=""
declare -x KUBERNETES_PUBLIC_ADDRESS=
declare -x INTERNAL_IP_BASE=172.19.180.
declare -ax NODES=(1 2 3 4)
declare -x KEY_ALGO="rsa"
declare -x KEY_SIZE=2048
declare -ax CSR_FILE=(ca admin p1 p2 p3 p4\
 kube-controller-manager kube-proxy\
 kube-scheduler kubernetes service-account)
declare -ax CSR_CN=(Kubernetes admin system:node:p1\
 system:node:p2 system:node:p3 system:node:p4\
 system:kube-controller-manager system:kube-proxy\
 system:kube-scheduler kubernetes  service-accounts)

declare -x KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

# Make the pki directory and copy in the ca config.
mkdir -p ~/pki
cp ca-config.json ~/pki
cp cert_data.json ~/pki
cd ~/pki


# gen_csr file cn
# E.g. gen_csr admin-csr admin
function gen_csr {
    CN=${2} envsubst < ../cert_data.json > ${1}-csr.json
}

# Create the JSON config files.
COUNT=0
for cn in ${CSR_CN[@]}; do
    gen_csr ${CSR_FILE[COUNT]} ${cn}
    ((COUNT=COUNT+1))
done


# Generate the Certificate Authority.
# The ca-config.json has no real variables so it is included.
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

for cert in ${STD[@]}; do
 cfssl gencert  -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes $cert-csr.json | cfssljson -bare $cert
done

# Generate node certificates.
for node in ${NODES[*]}; do
    INTERNAL_IP=${INTERNAL_IP_BASE}${node}
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=p${node},${INTERNAL_IP} -profile=kubernetes p${node}-csr.json | cfssljson -bare p${node}
done

# Generate API certificate.
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${INTERNAL_IP_BASE}254,rpi-k8s-master,rpi-k8s-master.local,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
