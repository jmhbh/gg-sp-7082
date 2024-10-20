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

Create kind cluster
```shell
kind create cluster --name solo-test-cluster
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
- Deploy the HTTPRoute

```
./setup.sh
```

## Reproducing the issue (local)

Port forward the gloo-proxy-gateway

```shell
kubectl port-forward -n ingress-gw deploy/gloo-proxy-gw 8080:8080
```

Note that we deployed Gloo Gateway with the watchNamespace API enabled for the `ingress-gw` namespace so the following requests should work and yield the following results.

### Request 1

```shell
curl  http://api.example.com:8080/get -H "allow: true"
```

Expected result:
```
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Allow": [
      "true"
    ],
    "Host": [
      "api.example.com:8080"
    ],
    "User-Agent": [
      "curl/8.8.0"
    ],
    "X-Envoy-Expected-Rq-Timeout-Ms": [
      "15000"
    ],
    "X-Forwarded-Proto": [
      "http"
    ],
    "X-Request-Id": [
      "7f1c0287-84fc-42b5-9bda-82f7feb69d99"
    ]
  },
  "origin": "10.244.0.13:46524",
  "url": "http://api.example.com:8080/get"
}
```

### Request 2

```shell
curl  http://api.example.com:8080/get
```

Expected result:
```
Rejected%
```

### Observe downstream effect of control plane crash

Now let us observe the downstream effect of the segfault bug by removing `ingress-gw` from the watchNamespace list to see if the data plane is affected.

```shell
kubectl apply -f settings/settings.yaml
```

Make the same requests again, notice that both requests will result in the same response as the ext-auth-service fails to find the authConfig due to translation not completing as a result of the control plane crash.

```shell
curl -v http://api.example.com:8080/get -H "allow: true"
```

```shell
curl -v http://api.example.com:8080/get
```

Expected result:
```
* Host api.example.com:8080 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:8080...
* Connected to api.example.com (127.0.0.1) port 8080
> GET /get HTTP/1.1
> Host: api.example.com:8080
> User-Agent: curl/8.8.0
> Accept: */*
> allow: true
>
* Request completely sent off
< HTTP/1.1 403 Forbidden
< date: Sun, 20 Oct 2024 17:36:00 GMT
< server: envoy
< content-length: 0
<
* Connection #0 to host api.example.com left intact
```