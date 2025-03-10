/**
 * # Azure AD Kubernetes API Proxy
 * Adds [`azad-kube-proxy`](https://github.com/XenitAB/azad-kube-proxy) to a Kubernetes clusters.
 *
 * ## Configuring Azure AD Applications
 *
 * ### Azure AD App: azad-kube-proxy
 *
 * ```shell
 * ENVIRONMENT="dev"
 * TENANT_ID=$(az account show --output tsv --query tenantId)
 * AZ_APP_NAME="aks-${ENVIRONMENT}"
 * AZ_APP_URI="https://aks.${ENVIRONMENT}.example.com"
 * AZ_APP_ID=$(az ad app create --display-name ${AZ_APP_NAME} --identifier-uris ${AZ_APP_URI} --query appId -o tsv)
 * AZ_APP_OBJECT_ID=$(az ad app show --id ${AZ_APP_ID} --output tsv --query objectId)
 * AZ_APP_PERMISSION_ID=$(az ad app show --id ${AZ_APP_ID} --output tsv --query "oauth2Permissions[0].id")
 * az rest --method PATCH --uri "https://graph.microsoft.com/beta/applications/${AZ_APP_OBJECT_ID}" --body '{"api":{"requestedAccessTokenVersion": 2}}'
 * # Add Azure CLI as allowed client
 * az rest --method PATCH --uri "https://graph.microsoft.com/beta/applications/${AZ_APP_OBJECT_ID}" --body "{\"api\":{\"preAuthorizedApplications\":[{\"appId\":\"04b07795-8ddb-461a-bbee-02f9e1bf7b46\",\"permissionIds\":[\"${AZ_APP_PERMISSION_ID}\"]}]}}"
 * # This tag will enable discovery using kubectl azad-proxy discover
 * az rest --method PATCH --uri "https://graph.microsoft.com/beta/applications/${AZ_APP_OBJECT_ID}" --body '{"tags":["azad-kube-proxy"]}'
 * AZ_APP_SECRET=$(az ad sp credential reset --name ${AZ_APP_ID} --credential-description "azad-kube-proxy" --output tsv --query password)
 * az ad app permission add --id ${AZ_APP_ID} --api 00000003-0000-0000-c000-000000000000 --api-permissions 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
 * az ad app permission admin-consent --id ${AZ_APP_ID}
 * ```
 *
 * ### Azure KeyVault
 *
 * ```shell
 * JSON_FMT='{"client_id":"%s","client_secret":"%s","tenant_id":"%s"}'
 * KV_SECRET=$(printf "${JSON_FMT}" "${AZ_APP_ID}" "${AZ_APP_SECRET}" "${TENANT_ID}")
 * az keyvault secret set --vault-name <keyvault name> --name azad-kube-proxy --value "${KV_SECRET}"
 * ```
 *
 * ## Terraform example (aks-core)
 *
 * ```terraform
 * data "azurerm_key_vault_secret" "azad_kube_proxy" {
 *   key_vault_id = data.azurerm_key_vault.core.id
 *   name         = "azad-kube-proxy"
 * }
 *
 * module "aks_core" {
 *   source = "github.com/xenitab/terraform-modules//modules/kubernetes/aks-core?ref=[ref]"
 *
 *   [...]
 *
 *   azad_kube_proxy_enabled = true
 *   azad_kube_proxy_config = {
 *     fqdn                  = "aks.${var.dns_zone}"
 *     azure_ad_group_prefix = var.aks_group_name_prefix
 *     allowed_ips           = var.aks_authorized_ips
 *     azure_ad_app = {
 *       client_id     = jsondecode(data.azurerm_key_vault_secret.azad_kube_proxy.value).client_id
 *       client_secret = jsondecode(data.azurerm_key_vault_secret.azad_kube_proxy.value).client_secret
 *       tenant_id     = jsondecode(data.azurerm_key_vault_secret.azad_kube_proxy.value).tenant_id
 *     }
 *   }
 * }
 * ```
 *
*/

terraform {
  required_version = "0.15.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.8.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}

locals {
  aad_config = {
    CLIENT_ID     = var.azure_ad_app.client_id
    CLIENT_SECRET = var.azure_ad_app.client_secret
    TENANT_ID     = var.azure_ad_app.tenant_id
  }
  secret_data = local.aad_config
  values = templatefile("${path.module}/templates/values.yaml.tpl", {
    fqdn                  = var.fqdn,
    allowed_ips_csv       = join(",", var.allowed_ips),
    azure_ad_group_prefix = var.azure_ad_group_prefix
  })
}

resource "kubernetes_namespace" "this" {
  metadata {
    labels = {
      name                = "azad-kube-proxy"
      "xkf.xenit.io/kind" = "platform"
    }
    name = "azad-kube-proxy"
  }
}

resource "kubernetes_secret" "this" {
  metadata {
    name      = "azad-kube-proxy"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = local.secret_data
}

resource "helm_release" "azad_kube_proxy" {
  depends_on  = [kubernetes_secret.this]
  repository  = "https://xenitab.github.io/azad-kube-proxy"
  chart       = "azad-kube-proxy"
  name        = "azad-kube-proxy"
  namespace   = kubernetes_namespace.this.metadata[0].name
  version     = "v0.0.30"
  max_history = 3
  values      = [local.values]
}
