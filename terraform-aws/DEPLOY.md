# Deploy Runbook — first bring-up on AWS

Ordered sequence for the **first** deploy. After this, normal changes flow through
CI/CD automatically and you never repeat these steps.

Account `864181438690` · Region `us-east-1` · Cluster `MicroservicesDemoCluster-Prasad`

For post-deploy health checks and teardown, see [VERIFY.md](./VERIFY.md).

---

## Why the order matters

Two things make a naive `terraform apply` produce a broken-looking cluster:

1. **ArgoCD syncs the instant it starts.** Every tag in `values-images.yaml` ships
   empty, which falls back to `images.tag` and then to `Chart.AppVersion`
   (`v0.10.5`). If ECR is still empty at that moment, all 11 pods land in
   `ImagePullBackOff` until CI pushes real images.

2. **Both workflows fire on the same push to `main`.** `deploy.yml` watches
   `src/**` + `helm-chart/**`; `infra.yml` watches `terraform-aws/**`. Push
   everything at once and they race — `infra.yml` can finish building the cluster
   before `deploy.yml` has finished pushing images, recreating problem 1.

The fix is to **fill ECR before the cluster exists**, by splitting the first push
in two so the workflows can't race.

---

## Phase 0 — One-time prerequisites

```bash
# State bucket (idempotent, safe to re-run). Already done if terraform init worked.
bash terraform-aws/bootstrap.sh

cd terraform-aws
terraform init
```

If the account has never used GitHub OIDC, create the provider once — the stack
reads it as a data source rather than creating it, so it must already exist:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
```

> Account `864181438690` already has this. Skip.

### Git housekeeping

The AWS work is currently **uncommitted**, and ArgoCD reads the chart *from
GitHub* — anything not pushed simply does not exist as far as the cluster is
concerned. Rename the branch to match what the workflows trigger on:

```bash
git branch -m master main
git push -u origin main
# Then: GitHub → Settings → Branches → change default branch to main
```

---

## Phase 1 — Create ECR + the CI role only

Everything here is effectively free (no compute), and it produces the role ARN
that CI needs before it can do anything.

```bash
terraform apply -target=module.ecr -target=module.github_oidc
```

> `-target` prints a warning about partial application. That is expected and
> correct here — we are deliberately building a prerequisite subset.

Creates: 11 ECR repositories + the `…-github-actions-role` IAM role.

```bash
terraform output github_actions_role_arn
```

Add that value to **GitHub → Settings → Secrets and variables → Actions** as:

| Secret | Value |
| --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::864181438690:role/MicroservicesDemoCluster-Prasad-github-actions-role` |

Also set **Settings → Actions → General → Workflow permissions** to
**Read and write**. Without it, `deploy.yml`'s second job cannot push the updated
`values.yaml` back to the repo, and the whole GitOps trigger silently never fires.

---

## Phase 2 — Fill ECR via CI (no cluster yet)

Push **everything except `terraform-aws/`**. That keeps `infra.yml` dormant while
`deploy.yml` does its work, so nothing races.

```bash
git add . ':!terraform-aws'
git commit -m "Online Boutique on AWS: helm chart, Istio gateway, ArgoCD app"
git push
```

`deploy.yml` now runs. This first run has no usable diff base, so it takes the
build-everything fallback — all 11 images, in parallel, ~5 min:

- **`changes`** decides which services to build (here: all of them).
- **`prepare`** resolves the shared tag (short git SHA) and ECR registry.
- **`build-and-push`** — one parallel job per service.
- **`update-values`** writes each service's tag into `helm-chart/values-images.yaml`
  and commits it with `[skip ci]`.

Confirm ECR actually has images before continuing — this is the check that makes
Phase 3 come up green:

```bash
aws ecr describe-images --repository-name frontend --region us-east-1 \
  --query 'imageDetails[].imageTags' --output text

git pull   # fetch the CI commit that set the real tags
cat helm-chart/values-images.yaml
```

Every `tag:` must now be a git SHA, **not** `""`.

> From the second push onward only the services you actually edited are rebuilt,
> and only their tags change — so only those Deployments roll. See
> [Per-service tags](#per-service-tags) below.

---

## Phase 3 — Build the cluster

```bash
terraform apply        # ~15-20 min: VPC → EKS → CoreDNS → Istio → ArgoCD → sync
```

Order Terraform enforces: VPC → EKS control plane → node groups → CoreDNS addon →
`istio-base` (CRDs) → `istiod` → `istio-ingressgateway` → ArgoCD → Application.

Because `values.yaml` already carries a real tag pointing at images that already
exist, **ArgoCD's very first sync is correct** — no `ImagePullBackOff` window.

Then work through [VERIFY.md](./VERIFY.md) to confirm node split, sidecar
injection (`2/2` READY), and get the NLB URL.

---

## Phase 4 — Hand infrastructure over to CI

```bash
git add terraform-aws
git commit -m "infra: EKS 1.34, S3 native state locking, OIDC data source"
git push
```

`infra.yml` runs `plan` then `apply`. **Expect a no-op** ("No changes"), since
Phase 3 already converged the state. That no-op is the proof CI and your laptop
resolve identical infrastructure — the reason `.terraform.lock.hcl` and
`terraform.tfvars` are now committed.

From here the loop is fully automatic:

```
edit src/**        → deploy.yml → ECR + values-images.yaml bump → ArgoCD syncs
edit terraform-aws → infra.yml  → terraform apply
```

---

## Per-service tags

Each service resolves its image tag as:

```
<service>.image.tag  →  images.tag  →  Chart.AppVersion
```

`helm-chart/values.yaml` is hand-owned. `helm-chart/values-images.yaml` is written
by CI and layered on top by ArgoCD (`valueFiles` order decides the winner). CI
never touches the commented file, so its structure survives.

**What that buys you.** Edit one service and push:

1. `changes` diffs against the previous commit and emits a matrix of just that service.
2. Only that image is built and pushed.
3. Only that service's tag is rewritten — the other ten keep the SHA they had.
4. Their rendered Deployments are therefore **byte-identical**, so the Kubernetes
   Deployment controller sees no change and performs **no rollout** for them.

Verified by rendering the chart before and after a single-service tag bump: the
diff across all 39 rendered manifests is exactly **one line**.

If instead a single global `images.tag` were used (the upstream chart's design),
that one edit would change the image string on all 11 Deployments and roll the
entire application every time.

**Why unchanged services can't just be skipped without this.** With a shared tag,
building only the edited service would leave the other ten pointing at
`<registry>/<service>:<newSHA>` — a tag that was never pushed — and they would all
fall into `ImagePullBackOff`. Per-service tags are what make selective builds safe.

**Fallbacks.** `changes` rebuilds everything when the diff base is unusable: a
manual `workflow_dispatch`, the first push to a branch, or a force-push where the
old commit is gone. Building too much wastes minutes; building too little ships a
stale image silently, so it errs toward the former.

---

## Cost while running

| Component | Rate |
| --- | --- |
| EKS control plane (1.34, standard support) | $0.10/hr |
| 2× t3.medium system nodes (on-demand) | ~$0.083/hr |
| 2× t3.medium app nodes (spot) | ~$0.025/hr |
| NAT gateway | ~$0.045/hr + data |
| 2× NLB (istio-ingressgateway + argocd-server) | ~$0.045/hr |
| **Total** | **~$0.30/hr (~$7/day)** |

Staying on a version in **standard** support matters: 1.32/1.33 are in extended
support at **$0.60/hr** for the control plane — 6× more, for the same cluster.

Tear down with the ordered steps in [VERIFY.md](./VERIFY.md#6-teardown--dont-leave-nlbs-running).
Delete the Kubernetes `LoadBalancer` Services **before** `terraform destroy` —
Terraform does not own those NLBs and will happily leave them billing.

---

## Known sharp edges

- **CPU is the tight axis on app nodes, not memory.** Across 2× t3.medium with
  sidecars and daemonsets: **~3020m of ~3860m CPU (78%)** vs ~3224Mi of ~6600Mi
  memory (49%). It fits, but there is little CPU headroom — a spot reclaim will
  leave pods `Pending` until the replacement node joins. Bump
  `app_instance_types` to `t3.large` if that bites.
- **`selfHeal: true`** means manual `kubectl edit` is reverted within ~3 min. Change
  git, not the cluster.
- **Private repo?** The ArgoCD Application uses an anonymous HTTPS `repoURL`. If the
  GitHub repo is private, ArgoCD cannot read it and the Application stays
  `Unknown` — register a repo credential in ArgoCD, or make the repo public.
- **CI role vs cluster RBAC.** The cluster is created by your local IAM user, which
  becomes its admin. The GitHub Actions role is a *different* principal. It only
  needs that access if CI ever has to re-run the `kubectl` provisioners in
  `argocd.tf` (i.e. a from-scratch rebuild). If that day comes, grant it with an
  EKS access entry rather than editing `aws-auth`.
