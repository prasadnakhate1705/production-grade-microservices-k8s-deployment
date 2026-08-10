# Demo Runbook — Verify & Teardown

Quick checks to confirm the cluster came up correctly, plus a clean teardown so you
don't leave billable resources running. Designed for a short (< 5 hour) demo window.

Region: `us-east-1` · Cluster: `MicroservicesDemoCluster-Prasad` · App namespace: `e-commerce-app`

---

## 0. Bring it up

```bash
cd terraform-aws
terraform init
terraform apply        # ~15-20 min: VPC → EKS → Istio → ArgoCD → app sync
```

`terraform apply` configures your kubeconfig automatically (the `update_kubeconfig`
step). If `kubectl` can't reach the cluster, re-run it manually:

```bash
aws eks update-kubeconfig --region us-east-1 --name MicroservicesDemoCluster-Prasad
```

---

## 1. Nodes — system vs app split

```bash
kubectl get nodes -L role
```

Expect **4 nodes**: 2 with `ROLE=system`, 2 with `ROLE=app`.

```bash
# System nodes carry the dedicated=system taint; app nodes are untainted.
kubectl get nodes -l role=system -o jsonpath='{.items[*].spec.taints}'; echo
```

---

## 2. ArgoCD is pinned to system nodes

```bash
kubectl get pods -n argocd -o wide
```

Every `argocd-*` pod's node should be one of the **system** nodes (cross-check the
node names from step 1). If any landed on an app node, the pin patch didn't apply.

---

## 3. CoreDNS scheduled despite the taint

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

Both CoreDNS replicas should be `Running` (on system nodes). If they're `Pending`,
the toleration on the addon didn't take.

---

## 4. THE key check — sidecars injected

```bash
kubectl get pods -n e-commerce-app
```

Every microservice pod must show **`2/2` READY** (app container + `istio-proxy`).

- `2/2` → mesh is working ✓
- `1/1` → injection did NOT fire. Check the namespace label:
  ```bash
  kubectl get ns e-commerce-app -o jsonpath='{.metadata.labels}'; echo
  # must contain  istio-injection: enabled
  ```

Pods should be spread across the **2 app nodes** (`-o wide` to confirm). CPU is the
tight resource here (~75% of allocatable with sidecars), so a few `Pending` pods
after a Spot interruption is expected until the node is replaced.

---

## 5. Ingress routing — get the demo URL

```bash
# Confirm the Gateway selector matches the ingressgateway pod label.
kubectl get pods -n istio-system --show-labels | grep ingressgateway
# Look for  istio=ingressgateway  — that's what frontend-gateway's selector binds to.

# Gateway + VirtualService exist in the app namespace.
kubectl get gateway,virtualservice -n e-commerce-app

# The external NLB hostname — open this in a browser.
kubectl get svc -n istio-system istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

NLB provisioning takes 2-3 min after apply. If the page 404s, the VirtualService
isn't binding — recheck the Gateway selector label above.

### ArgoCD UI (optional)

```bash
kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# Username: admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

---

## 6. Teardown — don't leave NLBs running

The `istio-ingressgateway` and ArgoCD `LoadBalancer` Services each provision an AWS
NLB. Terraform does **not** own those (Kubernetes created them), so deleting them
first prevents orphaned load balancers that keep billing after `destroy`.

```bash
# 1. Delete the ArgoCD Application first — its finalizer prunes all app workloads.
kubectl delete application online-boutique -n argocd

# 2. Delete the LoadBalancer Services so their NLBs are released.
kubectl delete svc istio-ingressgateway -n istio-system
kubectl delete svc argocd-server -n argocd

# 3. Tear down the infrastructure.
cd terraform-aws
terraform destroy
```

### Confirm nothing is orphaned

```bash
# Should return no load balancers tagged for this cluster.
aws elbv2 describe-load-balancers --region us-east-1 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerName"

# Sanity-check for leftover EBS volumes / EIPs.
aws ec2 describe-volumes --region us-east-1 \
  --filters Name=status,Values=available --query 'Volumes[].VolumeId'
```

> 💡 The EKS control plane bills ~\$0.10/hr whenever the cluster exists, independent
> of workload. Run `terraform destroy` as soon as the demo is done.
