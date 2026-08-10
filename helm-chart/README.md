# Helm chart

Deploys the 11 microservices plus an in-cluster Redis for the cart.

In normal operation you do not run `helm` by hand — ArgoCD renders this chart
straight from git (see [`argocd/application.yaml.tpl`](../argocd/application.yaml.tpl))
and syncs it into the `e-commerce-app` namespace. The commands below are for
local inspection and one-off testing.

## Value files

| File | Owner | Contents |
| --- | --- | --- |
| `values.yaml` | hand-edited | everything except image tags; CI never rewrites it, so comments survive |
| `values-images.yaml` | CI | per-service image tags, rewritten on every deploy |

ArgoCD layers them in that order, so a one-service change rolls only that one
Deployment — the other ten keep the tag they already had and render byte-identical.

## Render locally

```sh
helm template ob . \
    --namespace e-commerce-app \
    --set images.repository=<account>.dkr.ecr.<region>.amazonaws.com
```

`images.repository` has no usable default — the ArgoCD Application injects the
real ECR registry as a parameter, since it depends on the AWS account.

## Install directly (bypasses ArgoCD)

```sh
helm upgrade ob . \
    --install \
    --create-namespace \
    --namespace e-commerce-app \
    --set images.repository=<account>.dkr.ecr.<region>.amazonaws.com \
    --set frontend.platform=aws
```

Note that ArgoCD has `selfHeal: true`, so if the Application already exists it
will revert anything you install this way within a few minutes.

## Hardening toggles

All default to `false`. They are independent and can be combined:

```sh
    --set serviceAccounts.create=true \
    --set networkPolicies.create=true \
    --set authorizationPolicies.create=true \
    --set sidecars.create=true \
    --set seccompProfile.enable=true
```

`networkPolicies`, `authorizationPolicies` and `sidecars` all assume a service
mesh is present — turning them on without Istio installed will cut off traffic
between services.

## Ingress

`frontend.istioGateway.create=true` (the default) creates a Gateway +
VirtualService that routes the Istio ingress-gateway's NLB to the frontend.

`frontend.externalService` is deliberately `false`: setting it to `true` spins
up a second AWS NLB pointing straight at the frontend, bypassing the mesh.

For the full list of configurations, see [values.yaml](./values.yaml).
