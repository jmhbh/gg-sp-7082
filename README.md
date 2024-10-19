# Gloo Gateway SP-7082 Reproducer

## Installation

Add Gloo Gateway Helm repo:
```
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
```

Export your Gloo Gateway License Key to an environment variable:
```
export GLOO_GATEWAY_LICENSE_KEY={your license key}
```

Install Gloo Gateway:
```
cd install
./install-gloo-gateway-with-helm.sh
```

> NOTE
> The Gloo Gateway version that will be installed is set in a variable at the top of the `install/install-gloo-gateway-with-helm.sh` installation script.

> NOTE
> This installation has been configured to only watch the namespaces `gloo-system` and `httpbin`, but we're deploying our K8S Gateway API `Gateway`, `HTTPRoute` and `RouteOption` in the `ingress-gw` namespace.

## Setup the environment

Run the `install/setup.sh` script to setup the environment:

- Create the required namespaces
- Deploy the Gateways (Gloo Egde API and K8S Gateway API)
- Deploy the HTTPBin application
- Deploy the Reference Grants
- Deploy the RouteOption

```
./setup.sh
```

Note that this does not deploy the `HTTPRoute`, as that will crash the Gloo controller due to the bug that we're reproducing in this reproducer.

## Deploy the HTTPRoute

When we now deploy the `HTTPRoute`, the Gloo controller pod will crash

```
kubectl apply -f routes/api-example-com-httproute.yaml
```

This seems to be caused by the `ExtensionRef` in the `HTTPRoute` that points to a `RouteOption` that is a namespace that is not being watched by Gloo (see the `settings.watchNamespaces` configuration in the `install/gloo-gateway-helm-values.yaml` file.

The Gloo controller returns back to normal when we either:
- Remove the `ExtensionRef` pointing at the `RouteOption` from the `HTTPRoute`
- Add the `ingress-gw` namespace, in which we've deployed the `RouteOption` to the `watchNamespaces` list.