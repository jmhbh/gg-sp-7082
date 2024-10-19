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

```
panic: runtime error: invalid memory address or nil pointer dereference                                                                                                                                    │
│ [signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x2075fca]                                                                                                                                    │
│                                                                                                                                                                                                            │
│ goroutine 903 [running]:                                                                                                                                                                                   │
│ github.com/solo-io/gloo/projects/gateway/pkg/api/v1.(*RouteOption).SetNamespacedStatuses(0x529b900?, 0xc002bd6600?)                                                                                        │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gateway/pkg/api/v1/route_option.sk.go:54 +0xa                                                                                                    │
│ github.com/solo-io/solo-kit/pkg/utils/statusutils.setStatusForNamespace({0x6b88200, 0x0}, 0xc001d7c200, {0xc0000bc04e, 0xb})                                                                               │
│     /go/pkg/mod/github.com/solo-io/solo-kit@v0.35.4/pkg/utils/statusutils/client.go:49 +0x119                                                                                                              │
│ github.com/solo-io/solo-kit/pkg/utils/statusutils.(*NamespacedStatusesClient).SetStatus(...)                                                                                                               │
│     /go/pkg/mod/github.com/solo-io/solo-kit@v0.35.4/pkg/utils/statusutils/client.go:28                                                                                                                     │
│ github.com/solo-io/gloo/pkg/utils/statusutils.(*HybridStatusClient).SetStatus(0xa420ca0?, {0x6b88200?, 0x0?}, 0x0?)                                                                                        │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/pkg/utils/statusutils/status.go:53 +0x78                                                                                                                  │
│ github.com/solo-io/solo-kit/pkg/api/v2/reporter.(*reporter).WriteReports(0xc002396930, {0x6b77cc8, 0xc002bd65d0}, 0xc002bd65a0, 0xc002477b30)                                                              │
│     /go/pkg/mod/github.com/solo-io/solo-kit@v0.35.4/pkg/api/v2/reporter/reporter.go:381 +0x6d2                                                                                                             │
│ github.com/solo-io/gloo/projects/gateway2/translator/plugins/routeoptions.(*plugin).ApplyStatusPlugin(0xc001310320, {0x6b77cc8, 0xc002bd6540}, 0xa?)                                                       │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gateway2/translator/plugins/routeoptions/route_options_plugin.go:149 +0x328                                                                      │
│ github.com/solo-io/gloo/projects/gateway2/status.(*statusSyncer).applyStatusPlugins(0xc002bb3178, {0x6b77cc8?, 0xc002b99c50?}, {0xc002537ea8, 0x1, 0x5cd5e00?})                                            │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gateway2/status/status_syncer.go:167 +0x2e9                                                                                                      │
│ github.com/solo-io/gloo/projects/gateway2/status.(*statusSyncerFactory).HandleProxyReports(0xc001d7a260, {0x6b77cc8, 0xc002b99c50}, {0xc002537e78, 0x1, 0xc0013a9901?})                                    │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gateway2/status/status_syncer.go:131 +0x895                                                                                                      │
│ github.com/solo-io/gloo/projects/gloo/pkg/syncer.(*translatorSyncer).syncEnvoy(0xc00183c840, {0x6b77d00?, 0xc000dc5040?}, 0xc001b55980, 0xc002b986f0)                                                      │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gloo/pkg/syncer/envoy_translator_syncer.go:194 +0x1ced                                                                                           │
│ github.com/solo-io/gloo/projects/gloo/pkg/syncer.(*translatorSyncer).Sync(0xc00183c840, {0x6b77d00, 0xc000dc5040}, 0xc001b55980)                                                                           │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gloo/pkg/syncer/translator_syncer.go:135 +0x165                                                                                                  │
│ github.com/solo-io/gloo/projects/gloo/pkg/api/v1/gloosnapshot.ApiSyncers.Sync({0xc001d2f480?, 0x6b77cc8?, 0xc002b8b1d0?}, {0x6b77d00, 0xc000dc5040}, 0xc001b55980)                                         │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gloo/pkg/api/v1/gloosnapshot/api_event_loop.sk.go:50 +0x8d                                                                                       │
│ github.com/solo-io/gloo/projects/gloo/pkg/api/v1/gloosnapshot.(*apiEventLoop).Run.func1()                                                                                                                  │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gloo/pkg/api/v1/gloosnapshot/api_event_loop.sk.go:124 +0x2b5                                                                                     │
│ created by github.com/solo-io/gloo/projects/gloo/pkg/api/v1/gloosnapshot.(*apiEventLoop).Run in goroutine 277                                                                                              │
│     /go/pkg/mod/github.com/solo-io/gloo@v1.17.13/projects/gloo/pkg/api/v1/gloosnapshot/api_event_loop.sk.go:88 +0x378
```

This seems to be caused by the `ExtensionRef` in the `HTTPRoute` that points to a `RouteOption` that is a namespace that is not being watched by Gloo (see the `settings.watchNamespaces` configuration in the `install/gloo-gateway-helm-values.yaml` file.

The Gloo controller returns back to normal when we either:
- Remove the `ExtensionRef` pointing at the `RouteOption` from the `HTTPRoute`
- Add the `ingress-gw` namespace, in which we've deployed the `RouteOption` to the `watchNamespaces` list.