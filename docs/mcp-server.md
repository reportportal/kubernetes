# ReportPortal MCP Server Deployment Guide

The ReportPortal Helm chart can deploy the [ReportPortal MCP Server](https://reportportal.io/docs/external-integrations/MCPServer/) as an optional service. It connects AI clients such as Cursor, Claude Code, and GitHub Copilot to ReportPortal through the Model Context Protocol (MCP).

The service is disabled by default. When enabled, the chart:

- runs the MCP server in HTTP mode on port `8080`;
- connects it to the in-cluster ReportPortal API service;
- exposes `/mcp` through the existing ReportPortal Ingress or Gateway API route;
- authenticates each request with the caller's ReportPortal API token.

## Prerequisites

- A working ReportPortal installation from this Helm chart
- An enabled Ingress or Gateway API route for external access
- A ReportPortal API token for each MCP client
- Access to a ReportPortal project

The MCP server does not store a shared ReportPortal token. Clients send their own token with each request.

## Enable the MCP Server

Add the ReportPortal chart repository if it is not already configured:

```bash
helm repo add reportportal https://k8s.reportportal.io
helm repo update
```

Install a new ReportPortal release:

```bash
helm install reportportal reportportal/reportportal \
  --namespace reportportal \
  --create-namespace \
  --set uat.superadminInitPasswd.password="ChangeMe" \
  --set mcp.enabled=true
```

Or enable MCP on an existing release:

```bash
helm upgrade reportportal reportportal/reportportal \
  --namespace reportportal \
  --reuse-values \
  --set mcp.enabled=true
```

For additional MCP configuration, create a `values-mcp.yaml` file and pass it with `-f values-mcp.yaml` instead of using `--set mcp.enabled=true`:

```yaml
mcp:
  enabled: true
  analyticsOff: true
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
```

Verify the workload:

```bash
kubectl get deployment,service \
  --namespace reportportal \
  -l app.kubernetes.io/instance=reportportal

kubectl logs \
  --namespace reportportal \
  deployment/reportportal-mcp
```

Resource names include the Helm release name and can differ when name overrides are used.

## MCP Endpoint

The MCP route uses the same hostname and base path as ReportPortal:

```text
https://<reportportal-host>/<base-path>/mcp
```

For example:

- `ingress.hosts: [reportportal.example.com]` and an empty `ingress.path` produce `https://reportportal.example.com/mcp`.
- `ingress.path: /reportportal` produces `https://reportportal.example.com/reportportal/mcp`.
- Gateway API uses `gatewayAPI.hostnames` and `gatewayAPI.path` in the same way.

If neither Ingress nor Gateway API is enabled, the MCP server is available only inside the cluster at:

```text
http://<release-fullname>-mcp:8080/mcp
```

## Authentication and Project Selection

Every MCP request must include a ReportPortal API token:

```text
Authorization: Bearer <reportportal-api-token>
```

To select a project, send the optional `X-Project` header:

```text
X-Project: <reportportal-project>
```

The token must have access to the selected project. Do not place API tokens in Helm values or Kubernetes manifests.

## Configure Cursor

Open **Cursor Settings → Tools & MCP → Add Custom MCP**, then add the remote server to `mcp.json`:

```json
{
  "mcpServers": {
    "reportportal": {
      "url": "https://reportportal.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${RP_API_TOKEN}",
        "X-Project": "my-project"
      }
    }
  }
}
```

Set `RP_API_TOKEN` in the environment used to start Cursor, then restart Cursor after changing the MCP configuration.

## Configure Claude Code

Add the remote MCP endpoint:

```bash
claude mcp add-json reportportal \
  '{"url":"https://reportportal.example.com/mcp","headers":{"Authorization":"Bearer ${RP_API_TOKEN}","X-Project":"my-project"}}'
```

Use `-s project` if the configuration should be shared through the project's `.mcp.json`.

Other HTTP-capable MCP clients use the same endpoint and headers. See the [ReportPortal MCP Server documentation](https://reportportal.io/docs/external-integrations/MCPServer/) for additional client examples.

## Configure MCP Resources and Runtime

Example production overrides:

```yaml
mcp:
  enabled: true
  analyticsOff: true
  connectionTimeout: 60
  maxWorkers: 8
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

The chart adds a built-in init container that waits for the ReportPortal API pod before starting MCP. Its requests and limits come from `global.initContainerResources`; `mcp.initContainerResources` is used only when the global value is empty.

Additional environment variables can be supplied through `mcp.extraEnvs`. See the [Parameters Reference](parameters-reference.md#mcp-server-configuration) for all available values.

## Private CA for In-Cluster HTTPS

By default, the MCP server communicates with the ReportPortal API over the in-cluster protocol selected by `k8s.networking.ssl`.

When in-cluster HTTPS uses a private CA, create a Secret containing the PEM certificate:

```bash
kubectl create secret generic reportportal-ca \
  --namespace reportportal \
  --from-file=ca.crt=/path/to/ca.crt
```

Reference the Secret:

```yaml
k8s:
  networking:
    ssl: true

mcp:
  enabled: true
  tls:
    caCert:
      secretName: reportportal-ca
      key: ca.crt
```

The chart mounts the certificate read-only and sets `RP_TLS_CA_CERT` automatically.

For temporary testing only, certificate verification can be disabled:

```yaml
mcp:
  tls:
    insecure: true
```

`tls.insecure` and `tls.caCert.secretName` are mutually exclusive.

## Ingress Timeouts

MCP Streamable HTTP sessions can be long-lived. Configure suitable timeouts on the shared ReportPortal Ingress or load balancer.

NGINX example:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

AWS ALB example:

```yaml
ingress:
  annotations:
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=3600
```

Gateway API timeout configuration depends on the selected Gateway controller.

## Troubleshooting

Check the MCP health endpoint from inside the cluster:

```bash
kubectl run mcp-health-check \
  --namespace reportportal \
  --rm -i --restart=Never \
  --image=curlimages/curl \
  -- http://reportportal-mcp:8080/health
```

Common failures:

- `401 Unauthorized`: the `Authorization` header is missing or the token is invalid.
- `403 Forbidden`: the token does not have access to the project selected by `X-Project`.
- `404 Not Found`: confirm that the client URL ends with `/mcp` and includes the configured ReportPortal base path.
- Connection timeout: verify Ingress/load-balancer timeouts and connectivity from the MCP pod to the API service.
- TLS verification error: verify the CA Secret name, key, namespace, and PEM contents.

