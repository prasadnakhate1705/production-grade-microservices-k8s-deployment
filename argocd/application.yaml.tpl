apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: e-commerce-microservices
  namespace: argocd
  # Tells ArgoCD to delete all managed K8s resources when this Application is deleted
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/REPLACE_GITHUB_REPO
    targetRevision: main
    path: helm-chart            # where the Helm chart lives in the repo

    helm:
      # Both files are read from the repo. Order matters — later files win:
      #   values.yaml        hand-owned: replica counts, resources, feature flags
      #   values-images.yaml CI-owned:   per-service image tags, rewritten each deploy
      # Splitting them keeps CI's mechanical rewrites away from the commented file,
      # and makes each deploy commit a minimal, reviewable diff.
      valueFiles:
        - values.yaml
        - values-images.yaml

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
    namespace: e-commerce-app                 # injection-enabled namespace (see managedNamespaceMetadata below)

  syncPolicy:
    automated:
      prune: true       # if you delete a service from helm-chart/, ArgoCD removes it from K8s
      selfHeal: true    # if someone runs kubectl manually and changes something, ArgoCD reverts it
    # Guarantees the destination namespace carries istio-injection=enabled, so every
    # pod ArgoCD deploys here gets an Envoy sidecar. Without this the namespace could
    # be created unlabeled and the mesh would never form.
    managedNamespaceMetadata:
      labels:
        istio-injection: enabled
    syncOptions:
      - CreateNamespace=true    # create namespace if it doesn't exist (labeled per above)
      - ServerSideApply=true    # use server-side apply (better for large resources)
    retry:
      limit: 3                  # retry failed syncs up to 3 times
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
