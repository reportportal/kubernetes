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

**When to apply:** After any change to `reportportal/values.yaml` defaults that affects validation (types, new parameters, or removed parameters).

**Steps:**

1. Read `reportportal/values.yaml` and identify changed defaults.
2. Update `reportportal/values.schema.json` to match. Regenerate as a starting point if needed:

   ```bash
   cd reportportal
   helm plugin install https://github.com/losisin/helm-values-schema-json.git --verify=false
   helm schema --values values.yaml --draft 7 --use-helm-docs --output values.schema.json
   ```

3. After regeneration, manually restore flexible-type and dependency rules (see below). Do not add schema annotations to `values.yaml`.
4. Commit both files in the same change.
5. Run `helm lint .` and `ct lint --charts .` in `reportportal/` to verify validation still passes.

### Post-regeneration fixes

Restore these after every `helm schema` run; the generator emits string-only / closed trees from `values.yaml` defaults:

1. **Image tags** — every `*.image.tag` must accept both unquoted numbers and quoted strings (YAML parses `18.4` as a number, `"18.4"` as a string):

   ```json
   "tag": {
     "oneOf": [
       { "type": "string" },
       { "type": "number" }
     ]
   }
   ```

2. **Other multi-type fields** — restore existing `oneOf` rules (for example `ingress.hosts`, `servicejobs.chunksize`, `gatewayAPI` listener/hostname refs).

3. **External dependencies** — keep `postgresql`, `rabbitmq`, `opensearch`, and `minio` as open passthrough objects so users can set any upstream chart values (ingress, resources, persistence, etc.). Do not regenerate a closed subset of dependency keys. Preferred shape:

   ```json
   "postgresql": {
     "type": "object",
     "additionalProperties": true,
     "properties": {
       "install": { "type": "boolean" },
       "image": {
         "type": "object",
         "additionalProperties": true,
         "properties": {
           "repository": { "type": "string" },
           "tag": {
             "oneOf": [
               { "type": "string" },
               { "type": "number" }
             ]
           }
         }
       }
     }
   }
   ```

   Apply the same pattern to `rabbitmq`, `opensearch`, and `minio`.

### Default-value rules

- Do **not** use YAML `null` for fields that overlays typically set to a string, array, or object (for example `database.endpoint`, `ingress.hosts`, `gatewayAPI.hostnames`). Use `""`, `[]`, or `{}` instead.
- Use `[]` for list fields such as `extraInitContainers`, not `{}`.
- Keep flexible-type rules in `values.schema.json`, not as inline comments in `values.yaml`.
