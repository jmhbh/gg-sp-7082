#!/bin/sh

pushd ..

# Create namespaces if they do not yet exist
# kubectl create namespace ingress-gw --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace httpbin --dry-run=client -o yaml | kubectl apply -f -

# Label the default namespace, so the gateway will accept the HTTPRoute from that namespace.
printf "\nLabel default namespace ...\n"
kubectl label namespaces default --overwrite shared-gateway-access="true"

# Deploy the HTTPBin application
printf "\nDeploy HTTPBin application ...\n"
kubectl apply -f apis/httpbin.yaml


# Deploy the Gateway

#K8S Gateway API
printf "\nDeploy K8S Gateway API Gateway ...\n"
kubectl create namespace ingress-gw --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f gateways/gw.yaml

# Reference Grants
printf "\nDeploy Reference Grants ...\n"
kubectl apply -f referencegrants/httpbin-ns/ingress-gw-ns-httproute-service-rg.yaml

# Deploy RouteOptions
printg "\nDeploy RouteOptions ...\n"
kubectl apply -f policies/routeoption.yaml

# HTTPRoute
printf "\nDeploy HTTPRoute ...\n"
kubectl apply -f routes/api-example-com-httproute.yaml

popd