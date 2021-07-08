#variable "environment" {
#  description = "The environment name to use for the deploy"
#  type        = string
#}

variable "namespaces" {
  description = "The namespaces that should be created in Kubernetes."
  type = list(
    object({
      name   = string
      labels = map(string)
      flux = object({
        enabled = bool
        github = object({
          repo = string
        })
        azure_devops = object({
          org  = string
          proj = string
          repo = string
        })
      })
    })
  )
}

variable "kubernetes_network_policy_default_deny" {
  description = "If network policies should by default deny cross namespace traffic"
  type        = bool
  default     = false
}

#variable "fluxcd_v2_enabled" {
#  description = "Should fluxcd-v2 be enabled"
#  type        = bool
#  default     = true
#}
#
#variable "fluxcd_v2_config" {
#  description = "Configuration for fluxcd-v2"
#  type = object({
#    type = string
#    github = object({
#      owner = string
#    })
#    azure_devops = object({
#      pat  = string
#      org  = string
#      proj = string
#    })
#  })
#}

variable "opa_gatekeeper_enabled" {
  description = "Should OPA Gatekeeper be enabled"
  type        = bool
  default     = true
}

#variable "external_secrets_enabled" {
#  description = "Should External Secrets be enabled"
#  type        = bool
#  default     = true
#}
#
#variable "external_secrets_config" {
#  description = "External Secrets configuration"
#  type = object({
#    role_arn = string
#  })
#}
#
#variable "cert_manager_enabled" {
#  description = "Should Cert Manager be enabled"
#  type        = bool
#  default     = true
#}
#
#variable "cert_manager_config" {
#  description = "Cert Manager configuration"
#  type = object({
#    notification_email = string
#    dns_zone           = string
#    role_arn           = string
#  })
#}

variable "ingress_nginx_enabled" {
  description = "Should Ingress NGINX be enabled"
  type        = bool
  default     = true
}

#variable "external_dns_enabled" {
#  description = "Should External DNS be enabled"
#  type        = bool
#  default     = true
#}
#
#variable "external_dns_config" {
#  description = "External DNS configuration"
#  type = object({
#    role_arn = string
#  })
#}
#
#variable "velero_enabled" {
#  description = "Should Velero be enabled"
#  type        = bool
#  default     = false
#}
#
#variable "velero_config" {
#  description = "Velero configuration"
#  type = object({
#    role_arn     = string
#    s3_bucket_id = string
#  })
#}

variable "azad_kube_proxy_enabled" {
  description = "Should azad-kube-proxy be enabled"
  type        = bool
  default     = false
}

variable "azad_kube_proxy_config" {
  description = "The azad-kube-proxy configuration"
  type = object({
    fqdn                  = string
    dashboard             = string
    azure_ad_group_prefix = string
    allowed_ips           = list(string)
    azure_ad_app = object({
      client_id     = string
      client_secret = string
      tenant_id     = string
    })
    k8dash_config = object({
      client_id     = string
      client_secret = string
      scope         = string
    })
  })
  default = {
    fqdn                  = ""
    dashboard             = ""
    azure_ad_group_prefix = ""
    allowed_ips           = []
    azure_ad_app = {
      client_id     = ""
      client_secret = ""
      tenant_id     = ""
    }
    k8dash_config = {
      client_id     = ""
      client_secret = ""
      scope         = ""
    }
  }
}
