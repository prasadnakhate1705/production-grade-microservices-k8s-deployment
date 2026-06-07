variable "cluster_name" {
  type        = string
  description = "Used as a prefix/tag on ECR resources"
}

variable "service_names" {
  type        = list(string)
  description = "One ECR repo is created for each service name"
  default = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice"
  ]
}
