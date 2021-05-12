#!/usr/bin/env sh

aws --version
aws-iam-authenticator help
kubectl version
kubectl get all
helm repo ls
helm ls

kubectl create secret generic devops-secret --from-literal=PING_IDENTITY_DEVOPS_USER="${PING_IDENTITY_DEVOPS_USER}" --from-literal=PING_IDENTITY_DEVOPS_KEY="${PING_IDENTITY_DEVOPS_KEY}"