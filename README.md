# Online Boutique on AWS — EKS + Istio + ArgoCD

A GitOps deployment of an 11-service polyglot microservices application onto
Amazon EKS, built as a learning project.

The application code is the [Online Boutique][upstream] sample. Everything
around it — the AWS infrastructure, the mesh, the delivery pipeline — is this
repository's own work:

| Layer | What's here |
| --- | --- |
| Infrastructure | Terraform: VPC, EKS 1.34, two node groups (system on-demand / app spot), ECR, GitHub OIDC |
| Service mesh | Istio (base + istiod + ingress gateway), pinned to system nodes, NLB at the edge |
| Delivery | GitHub Actions builds 11 images → ECR; ArgoCD syncs the Helm chart from git |
| Packaging | Helm chart with split hand-owned / CI-owned value files |

## Architecture

11 microservices in 5 languages talking to each other over gRPC. The frontend
is the only service exposed outside the mesh.

[![Architecture](/docs/img/architecture-diagram.png)](/docs/img/architecture-diagram.png)

Protocol Buffer definitions live in [`./protos`](/protos).

| Service | Language | Port | Description |
| --- | --- | --- | --- |
| [frontend](/src/frontend) | Go | 8080 | HTTP server for the website. Generates session IDs for all users; no signup/login. |
| [cartservice](/src/cartservice) | C# | 7070 | Stores cart items in Redis and retrieves them. |
| [productcatalogservice](/src/productcatalogservice) | Go | 3550 | Product list from a JSON file, plus search and lookup. |
| [currencyservice](/src/currencyservice) | Node.js | 7000 | Converts between currencies using ECB rates. Highest QPS service. |
| [paymentservice](/src/paymentservice) | Node.js | 50051 | Charges a card (mock) and returns a transaction ID. |
| [shippingservice](/src/shippingservice) | Go | 50051 | Shipping cost estimates and shipping (mock). |
| [emailservice](/src/emailservice) | Python | 8080 | Sends order confirmation emails (mock). |
| [checkoutservice](/src/checkoutservice) | Go | 5050 | Orchestrates cart retrieval, payment, shipping and email. |
| [recommendationservice](/src/recommendationservice) | Python | 8080 | Recommends products based on cart contents. |
| [adservice](/src/adservice) | Java | 9555 | Text ads matched to context words. |
| [loadgenerator](/src/loadgenerator) | Python/Locust | — | Drives continuous realistic shopping traffic at the frontend. |

Plus an in-cluster `redis-cart` backing the cart service.

## Deploying

Bring-up is ordered — ECR has to be populated before the cluster exists, or
ArgoCD's first sync lands on images that aren't there yet. The runbook covers
that sequence:

- **[terraform-aws/DEPLOY.md](/terraform-aws/DEPLOY.md)** — first bring-up, phase by phase
- **[terraform-aws/VERIFY.md](/terraform-aws/VERIFY.md)** — health checks and teardown
- **[helm-chart/README.md](/helm-chart/README.md)** — chart values and local rendering

Once deployed, the loop is automatic:

```
edit src/**        → deploy.yml → build → ECR → values-images.yaml bump → ArgoCD syncs
edit terraform-aws → infra.yml  → terraform plan → apply
```

## Screenshots

| Home Page | Checkout Screen |
| --- | --- |
| [![Store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

## Differences from upstream

This fork is AWS-only. Removed: the GKE/Cloud Operations integrations (Cloud
Profiler, Cloud Trace exporters, the Google Cloud OpenTelemetry collector),
Spanner as a cart backend, the Kustomize variants, Skaffold, and the
cloud-vendor-specific shopping assistant service. Added: everything in the
table at the top.

## Attribution

The application source under [`/src`](/src) and [`/protos`](/protos) is derived
from [GoogleCloudPlatform/microservices-demo][upstream], licensed under the
Apache License 2.0. See [LICENSE](/LICENSE). Modifications are described above.

[upstream]: https://github.com/GoogleCloudPlatform/microservices-demo
