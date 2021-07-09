#!/bin/bash

# Created by Mauro Matsudo
echo "Digite o nome do usuário a ser criado"
read user
echo "Didite o nome do grupo que o usuário fará parte"
read group

# Veriy where the cetificates will be stored
if test -d "/home/$user" 
  then
  dir="/home/$user/.cert"
  configDir="/home/$user/.kube"
else
  echo "O arquivo home para o usuário $user não foi encontrado."
  dir="./.cert-$user"
  configDir="./.kube-$user"
fi
echo "Os certificados serão criados em $dir"
mkdir $dir
mkdir $configDir

# create the certificates  
openssl genrsa -out $dir/$user.key 2048
openssl req -new -key $dir/$user.key -subj "/CN=$user/O=$group" -out $dir/$user.csr
openssl x509 -req -in $dir/$user.csr -CA /etc/kubernetes/pki/ca.crt -CAkey \
  /etc/kubernetes/pki/ca.key -CAcreateserial -out $dir/$user.crt -days 720

# cofigurar kubectl para acessar o cluster
echo "apiVersion: v1" > $configDir/config
echo "kind: Config" > $configDir/config
echo "Como o kubectl deve chamar esse cluster? "
read clustername
echo "Como deve chamar o contexto que você acessará esse cluster através do kubectl?"
read contextname
echo "Como é o Control Plane Endpoint do cluster?"
read clusterAddr

kubectl config --kubeconfig=$configDir/config \
  set-cluster $clustername --server=https://$clusterAddr:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true
kubectl config --kubeconfig=$configDir/config \
  set-credentials $user \
  --client-key $dir/$user.key \
  --client-certificate $dir/$user.crt \
  --embed-certs=true
kubectl config --kubeconfig=$configDir/config \
  set-context $contextname \
  --cluster=$clustername --user=$user
kubectl config  --kubeconfig=$configDir/config \
  set current-context $contextname

# corrigir permissão dos arquivos que permitem acesso ao cluster
if test -d "/home/$user/.cert"
  then
  chown -R $user:$(id $user -g) $dir
  chown -R $user:$(id $user -g) $configDir
fi
