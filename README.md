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
kubectl patch settings default \
  -n gloo-system \
  --type='json' \
  -p='[{"op": "remove", "path": "/spec/watchNamespaces/2"}]'
```

Check the settings to confirm that the `ingress-gw` namespace has been removed from the watchNamespace list.
```shell
kubectl get settings.gloo.solo.io -A -oyaml
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

Check the ext-auth-server logs and see that the ext-auth-service is unable to find the updated auth configuration 
```json
{
  "level": "error",
  "ts": "2024-10-20T20:10:48Z",
  "logger": "ext-auth.ext-auth-service",
  "msg": "Auth Server does not contain auth configuration with the given ID",
  "version": "undefined",
  "x-request-id": "ae15cd6a-7aff-402f-a1e5-351b74cec68d",
  "RequestContext": {
    "AuthConfigId": "ingress-gw.custom-auth",
    "SourceType": "route",
    "SourceName": ""
  },
  "stacktrace": [
    "github.com/solo-io/ext-auth-service/pkg/service.(*authServer).Check",
    "\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.58.0-patch2/pkg/service/extauth.go:150",
    "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3._Authorization_Check_Handler.func1",
    "\t/go/pkg/mod/github.com/envoyproxy/go-control-plane@v0.12.1-0.20240326194405-485b2263e153/envoy/service/auth/v3/external_auth.pb.go:700",
    "github.com/solo-io/ext-auth-service/pkg/server.Server.Run.GrpcUnaryServerHealthCheckerInterceptor.func9",
    "\t/go/pkg/mod/github.com/solo-io/go-utils@v0.25.3/healthchecker/grpc.go:69",
    "google.golang.org/grpc.getChainUnaryHandler.func1",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1203",
    "github.com/solo-io/ext-auth-service/pkg/server.Server.Run.requestIdInterceptor.func7",
    "\t/go/pkg/mod/github.com/solo-io/ext-auth-service@v0.58.0-patch2/pkg/server/logging.go:86",
    "google.golang.org/grpc.getChainUnaryHandler.func1",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1203",
    "github.com/grpc-ecosystem/go-grpc-middleware/logging/zap.UnaryServerInterceptor.func1",
    "\t/go/pkg/mod/github.com/grpc-ecosystem/go-grpc-middleware@v1.4.0/logging/zap/server_interceptors.go:31",
    "google.golang.org/grpc.NewServer.chainUnaryServerInterceptors.chainUnaryInterceptors.func1",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1194",
    "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3._Authorization_Check_Handler",
    "\t/go/pkg/mod/github.com/envoyproxy/go-control-plane@v0.12.1-0.20240326194405-485b2263e153/envoy/service/auth/v3/external_auth.pb.go:702",
    "google.golang.org/grpc.(*Server).processUnaryRPC",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1386",
    "google.golang.org/grpc.(*Server).handleStream",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1797",
    "google.golang.org/grpc.(*Server).serveStreams.func2.1",
    "\t/go/pkg/mod/google.golang.org/grpc@v1.62.2/server.go:1027"
  ]
}

```