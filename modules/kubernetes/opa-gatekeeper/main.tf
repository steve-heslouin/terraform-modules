/**
  * # OPA Gatekeeper
  *
  * Adds [`opa-gatekeeper`](https://github.com/open-policy-agent/gatekeeper) and [gatekeeper-library](https://github.com/xenitab/gatekeeper-library) to a Kubernetes clusters.
  *
  * Running the gatekeeper is a prerequirement for the library to work, as the library only adds different types of constraints that are used by gatekeeper.
  * Constraints are added through first creating a `ConstraintTemplate` and then adding a `Constraint` that enforces the template. The module constains a list of default
  * constraints in the `default_constraints` that are recomended to always be applied. These constraints are cloud agnostic and are either re-implemetnations of specific PSPs
  * or orginal constraints meant to enforce best practices. The default constraints will be added if you do not override this variable with either a list of different
  * constraints or an empty list. By default all namespaces expect those specified in the `excludes` namespaces will have the constraints enforced. What this means is that
  * if a resource does does comform to the constraints added by this module they will not be allowed to be created and will fail when applying.
  *
  * Constraints configuration are given in a specific object format that is compatible with the gatekeeper-library values format. The module makes sure that both templates
  * and the constraints are created. The example below would create a template with the kind of `K8sPSPVolumeTypes` which gatekeeper will create a CRD from, and a constraint
  * resource of kind `K8sPSPVolumeTypes` that enforces the rule.
  * ```hcl
  * {
  *   kind               = "K8sPSPVolumeTypes"
  *   name               = "psp-volume-types"
  *   enforcement_action = ""
  *   match = {
  *     kinds      = []
  *     namespaces = []
  *   }
  *   parameters = {
  *     volumes = ["configMap", "downwardAPI", "emptyDir", "persistentVolumeClaim", "secret", "projected"]
  *   }
  * }
  * ```
  *
  * Certain fields in the configuration object are required while others are not. The `kind` and `name` field are obviously required as they determine which template and constraint
  * that should be created. Other fiels such as `enforcement_action`, `match.kinds`, `parameters` do not always have to be set as they receive default values from the Helm chart.
  * Check the [defaults file](https://github.com/XenitAB/gatekeeper-library/blob/master/charts/gatekeeper-library-constraints/generated/defaults.yaml) in gatekeeper-library to see
  * what the default values are. It is reccomended to leave the `match.kinds` to the default value as most constraints act on specific resource types, and the default value is
  * set to right right kind. With the configuration above the following template and constraint will be created. Note the `mathc.kinds` field in the constraint resource.
  * ```yaml
  * apiVersion: templates.gatekeeper.sh/v1beta1
  * kind: ConstraintTemplate
  * metadata:
  *   name: k8spspvolumetypes
  * spec:
  *   crd:
  *     spec:
  *       names:
  *         kind: K8sPSPVolumeTypes
  *       validation:
  *         openAPIV3Schema:
  *           properties:
  *             volumes:
  *               items:
  *                 type: string
  *               type: array
  *   targets:
  *   - target: admission.k8s.gatekeeper.sh
  *     rego: {REGO}
  * ---
  * apiVersion: constraints.gatekeeper.sh/v1beta1
  * kind: K8sPSPVolumeTypes
  * metadata:
  *   name: psp-volume-types
  * spec:
  *   enforcementAction: deny
  *   match:
  *     kinds:
  *     - apiGroups:
  *       - ""
  *       kinds:
  *       - Pod
  *   parameters:
  *     volumes:
  *     - configMap
  *     - downwardAPI
  *     - emptyDir
  *     - persistentVolumeClaim
  *     - secret
  *     - projected
  * ```
  *
  * New constraints have to be added to [gatekeeper-library](https://github.com/xenitab/gatekeeper-library) with a new version of the Helm chart. Then the Helm chart version
  * can be updated in the module, which enables use of the new constraints.
  *
  * The gatekeeper-library requires two Helm charts for things to work, one that first sets up `ConstraintTemplate` and after that one that creates the `Constraint`. This has
  * to be done as otherwise there would be a chicken and the egg problem with the CRDs created by the `ConstraintTemplate`. This behavior is not visibile outside of the module
  * as the same values are passed to both of the charts, there will never be a difference between the constraints created and the templates that exist.
  */

terraform {
  required_version = "0.15.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
    }
  }
}

locals {
  values = templatefile("${path.module}/templates/gatekeeper-library-values.yaml.tpl", {
    constraints         = concat((var.enable_default_constraints ? local.default_constraints : []), var.additional_constraints),
    assigns             = concat((var.enable_default_assigns ? local.default_assigns : []), var.additional_assigns),
    excluded_namespaces = var.excluded_namespaces
  })
}

resource "kubernetes_namespace" "this" {
  metadata {
    labels = {
      name                             = "gatekeeper-system"
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
      "xkf.xenit.io/kind"              = "platform"
    }
    name = "gatekeeper-system"
  }
}

resource "kubernetes_network_policy" "deny_default" {
  metadata {
    name      = "deny-default"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {}
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {}
      }
    }

    egress {
      to {
        namespace_selector {}
        pod_selector {
          match_labels = {
            k8s-app = "kube-dns"
          }
        }
      }

      ports {
        port     = 53
        protocol = "UDP"
      }
    }

    egress {
      to {
        pod_selector {}
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_scraping" {
  metadata {
    name      = "allow-scraping"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "gatekeeper"
        release = "gatekeeper"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "prometheus"
          }
        }
        pod_selector {
          match_labels = {
            app = "prometheus"
            "app.kubernetes.io/name" = "prometheus"
          }
        }
      }

      ports {
        port = "metrics"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_webhook" {
  metadata {
    name      = "allow-webhook"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "gatekeeper"
        control-plane = "controller-manager"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        ip_block {
          cidr = "192.0.2.0/24" # Egress CIDR block of AKS API Server
        }
      }

      from {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            component = "tunnel"
          }
        }
      }

      ports {
        port = "webhook-server"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_api_server" {
  metadata {
    name      = "allow-api-server"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "gatekeeper"
        release = "gatekeeper"
      }
    }

    policy_types = ["Egress"]

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        port     = 443
        protocol = "TCP"
      }
    }
  }
}

resource "helm_release" "gatekeeper" {
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  name       = "gatekeeper"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "3.5.1"
  values = [templatefile("${path.module}/templates/gatekeeper-values.yaml.tpl", {
    provider = var.cloud_provider
  })]
}

resource "helm_release" "gatekeeper_templates" {
  depends_on = [helm_release.gatekeeper]

  repository = "https://xenitab.github.io/gatekeeper-library/"
  chart      = "gatekeeper-library-templates"
  name       = "gatekeeper-library-templates"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "v0.7.1"
  values     = [local.values]
}

resource "helm_release" "gatekeeper_constraints" {
  depends_on = [helm_release.gatekeeper, helm_release.gatekeeper_templates]

  repository = "https://xenitab.github.io/gatekeeper-library/"
  chart      = "gatekeeper-library-constraints"
  name       = "gatekeeper-library-constraints"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "v0.7.1"
  values     = [local.values]
}
