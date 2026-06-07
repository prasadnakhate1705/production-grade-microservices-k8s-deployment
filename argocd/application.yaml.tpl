apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: online-boutique
  namespace: argocd
  # Tells ArgoCD to delete all managed K8s resources when this Application is deleted
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/REPLACE_GITHUB_REPO
    targetRevision: HEAD        # always track the latest commit on main
    path: helm-chart            # where the Helm chart lives in the repo

    helm:
      # values.yaml is read from the repo — CI updates images.tag here on every deploy
      valueFiles:
        - values.yaml

      # These parameters override values.yaml — set once, never change
      # images.repository is dynamic (depends on your AWS account) so we inject it here
      # rather than hardcoding it in values.yaml
      parameters:
        - name: images.repository
          value: REPLACE_ECR_REGISTRY
        - name: frontend.platform
          value: aws
        - name: loadGenerator.create
          value: "true"

  destination:
    server: https://kubernetes.default.svc   # deploy to the same cluster ArgoCD runs in
    namespace: default

  syncPolicy:
    automated:
      prune: true       # if you delete a service from helm-chart/, ArgoCD removes it from K8s
      selfHeal: true    # if someone runs kubectl manually and changes something, ArgoCD reverts it
    syncOptions:
      - CreateNamespace=true    # create namespace if it doesn't exist
      - ServerSideApply=true    # use server-side apply (better for large resources)
    retry:
      limit: 3                  # retry failed syncs up to 3 times
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
