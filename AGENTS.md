# Agent Instructions

## Keep `docs/README.md` in Sync with the `docs/` Directory

**When to apply:** Whenever you create, delete, or rename a file inside `docs/`, or change the title (`#` heading) of an existing doc.

**Steps:**

1. Read `docs/README.md`.
2. Apply the relevant change:
   - **New file** → add a bullet under the most appropriate section with the relative filename link and a one-line description of the guide's purpose.
   - **Deleted file** → remove its bullet from the list.
   - **Renamed file** → update the filename in the link.
   - **Title changed** → update the link label to match the new title.
3. Do not add or remove sections in `docs/README.md` unless a file truly belongs to a new category not covered by any existing section.

---

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

---

## Keep `reportportal/values.schema.json` in Sync with `reportportal/values.yaml`

**When to apply:** After any change to `reportportal/values.yaml` defaults or to `# @schema` annotations.

**Steps:**

1. Read `reportportal/values.yaml` and identify changed defaults.
2. Regenerate the schema:

   ```bash
   cd reportportal
   helm schema --values values.yaml --draft 7 --use-helm-docs --output values.schema.json
   ```

3. Commit both `values.yaml` and `values.schema.json` in the same change.
4. Run `helm lint .` in `reportportal/` to verify the chart still passes validation.

### Default-value rules

- Do **not** use YAML `null` for fields that overlays typically set to a string, array, or object (for example `database.endpoint`, `ingress.hosts`, `gatewayAPI.hostnames`). Use `""`, `[]`, or `{}` instead.
- Use `[]` for list fields such as `extraInitContainers`, not `{}`.
- When a field accepts multiple types, keep a safe default and add a `# @schema oneOf: [...]` annotation on the same line in `values.yaml`.
- Never commit a schema generated from stale `null` defaults; CI compares the committed schema to a freshly generated file on every PR.
