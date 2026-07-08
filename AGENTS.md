# Agent Instructions

## Sync `docs/parameters-reference.md` with `reportportal/values.yaml`

**When to apply:** After any change to `reportportal/values.yaml` — whether adding, removing, or modifying parameters.

**Steps:**

1. Read `reportportal/values.yaml` and `docs/parameters-reference.md` in parallel.
2. Identify what changed:
   - New parameters → add to the correct section table.
   - Removed parameters → delete their rows.
   - Changed default values → update the `Default` column to match `values.yaml`.
3. Write the updated `docs/parameters-reference.md` using the rules below.

### Format rules

- Keep the existing disclaimer block and section order unchanged.
- Each section is a `## Section Name` heading followed by a three-column markdown table:

  ```markdown
  | Parameter | Description | Default |
  |-----------|-------------|---------|
  | `foo.bar` | What it controls | `defaultValue` |
  ```

- Parameter: backtick-quoted dot-notation path (e.g. `` `global.clusterDomain` ``).
- Default: backtick-quoted value; use `""` for empty string, `[]` for empty list, `{}` for empty map.
- Preserve existing descriptions unless the parameter's semantics changed.
- Add new sections at the end only if no existing section fits the parameter's prefix.

### Section → key-prefix mapping

| Section | Covers |
|---------|--------|
| Global Configuration | `global.*` |
| Service Index Configuration | `serviceindex.*` |
| Service UI Configuration | `serviceui.*` |
| Service API Configuration | `serviceapi.*` |
| UAT (Authorization) Service Configuration | `uat.*` |
| Service Jobs Configuration | `servicejobs.*` |
| Service Analyzer Configuration | `serviceanalyzer.*` |
| Migrations Configuration | `migrations.*` |
| Database Configuration | `database.*` |
| Message Broker Configuration | `msgbroker.*` |
| Search Engine Configuration | `searchengine.*` |
| Storage Configuration | `storage.*` |
| Ingress Configuration | `ingress.*` |
| Gateway API Configuration | `gatewayAPI.*` |
| RBAC Configuration | `rbac.*` |
| Hooks Configuration | `hooks.*` |
| Resource Quota Configuration | `resourceQuota.*` |
| External Dependencies Configuration | `postgresql.*`, `rabbitmq.*`, `opensearch.*`, `minio.*` |
| Additional Configuration | `k8sWaitFor.*`, `kubectl.*`, `k8s.*` |
