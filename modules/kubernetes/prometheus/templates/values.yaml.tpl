# For more values see: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
# grafana is managed by the grafana-operator
grafana:
  enabled: false

kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false

kubeEtcd:
  enabled: false

# Specific for AKS kube-proxy label
kubeProxy:
  service:
    selector:
      component: kube-proxy

# We don't use alert manager in the cluster, we use thanos ruler
alertmanager:
  enabled: false

prometheus:
  enabled: false

kube-state-metrics:
  priorityClassName: "platform-low"
  podSecurityPolicy:
    enabled: false
  metricLabelsAllowlist:
    - "namespaces=[xkf.xenit.io/kind]"
  collectors:
    # Disable collection of configmaps and secrets to reduce amount of metrics
    #- configmaps
    #- secrets
    - certificatesigningrequests
    - cronjobs
    - daemonsets
    - deployments
    - endpoints
    - horizontalpodautoscalers
    - ingresses
    - jobs
    - limitranges
    - mutatingwebhookconfigurations
    - namespaces
    - networkpolicies
    - nodes
    - persistentvolumeclaims
    - persistentvolumes
    - poddisruptionbudgets
    - pods
    - replicasets
    - replicationcontrollers
    - resourcequotas
    - services
    - statefulsets
    - storageclasses
    - validatingwebhookconfigurations
    - volumeattachments
  # Specificly add verticalpodautoscalers to collectors
  %{ if vpa_enabled }
    - verticalpodautoscalers # not a default resource, see also: https://github.com/kubernetes/kube-state-metrics#enabling-verticalpodautoscalers
  %{ endif }
  prometheus:
    monitor:
      additionalLabels:
        xkf.xenit.io/monitoring: platform


commonLabels:
  xkf.xenit.io/monitoring: platform

global:
  rbac:
    pspEnabled: false

# We don't monitor the clusters locally
defaultRules:
  create: false

prometheusOperator:
  priorityClassName: "platform-low"

prometheus-node-exporter:
  priorityClassName: "platform-high"
  prometheus:
    monitor:
      additionalLabels:
        xkf.xenit.io/monitoring: platform
