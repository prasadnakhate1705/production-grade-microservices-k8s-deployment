region             = "us-east-1"
github_repo        = "prasadnakhate1705/production-grade-microservices-k8s-deployment" # OIDC trust is scoped to this exact owner/repo
cluster_name       = "MicroservicesDemoCluster-Prasad"
cluster_version    = "1.34"   # 1.32/1.33 are past standard support — extended support bills 6x on the control plane
istio_version      = "1.30.3" # supports K8s 1.32-1.36; keep in step with cluster_version
node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 4
vpc_cidr           = "10.0.0.0/16"
# NOTE: the app namespace (e-commerce-app) is deliberately NOT set here.
# ArgoCD owns it via CreateNamespace=true + managedNamespaceMetadata — see namespaces.tf.
