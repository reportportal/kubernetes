# HELM pre upgrade hook

Starting from version 24.1.3 we added the helm pre-upgrade hook to the chart.
This hook is used to delete the old jobs to resolve a kubernetes issue with the job name.

## ArgoCD Deployments

If you are deploying the ReportPortal helm chart with ArgoCD, set `global.argocd.enabled=true` in your values:

```yaml
global:
  argocd:
    enabled: true
```

This ensures proper resource ordering through Helm hook weights:

- Role (weight: 3)
- ServiceAccount (weight: 4)
- RoleBinding (weight: 5)
- Pre-upgrade cleanup Job (weight: 10)

## Standard Helm Deployments

For standard Helm deployments without ArgoCD, the hook doesn't work with the additional roles and role bindings. Before performing the helm upgrade you need to create the roles and role bindings manually:

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: HELM_RELEASE_NAME-service-manager
  namespace: default
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: HELM_RELEASE_NAME
    meta.helm.sh/release-namespace: default
rules:
  - apiGroups: ["", "batch"]
    resources: ["pods", "services", "jobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["delete"]
```

After that, you can apply the roles:

```shell
kubectl apply -f role.yaml && \
```

```yaml
# role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: HELM_RELEASE_NAME-user-binding
  namespace: default
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: HELM_RELEASE_NAME
    meta.helm.sh/release-namespace: default
subjects:
  - kind: ServiceAccount
    name: HELM_RELEASE_NAME
    namespace: default
roleRef:
  kind: Role
  name: HELM_RELEASE_NAME-service-manager
  apiGroup: rbac.authorization.k8s.io
```

Delete the old bindings and apply the new ones:

```shell
kubectl delete rolebinding HELM_RELEASE_NAME-user-binding -n default
kubectl apply -f role-binding.yaml
```

Then you can upgrade the helm release:

```shell
helm upgrade ${HELM_RELEASE_NAME}
```
