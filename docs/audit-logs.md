# Audit logs and log collection

When audit logging is enabled, the API service writes audit logs to a shared volume at `/var/log/reportportal/audit.log` inside the pod. The chart does not include a built-in log streamer. To ship these logs to a central backend (e.g. Elasticsearch, Loki, S3), add a **sidecar** using `serviceapi.extraContainers` (and optionally `serviceapi.extraVolumes` for config).

## Enable audit logging

In your values:

```yaml
serviceapi:
  auditLogs:
    enable: true
    loglevel: info  # or debug, etc.
```

This enables the `AUDIT_LOGGER` env in the API container and mounts the `audit-log-volume` at `/var/log` for the API container. Any additional container you add via `extraContainers` can mount the same volume name to read the log file.

## Gather logs with a sidecar (extraContainers)

Use `serviceapi.extraContainers` to add a log collector that runs alongside the API and reads from the audit log volume. The volume is available as `audit-log-volume` and the log path is `/var/log/reportportal/audit.log`.

### Example: Fluent Bit sidecar

Add a Fluent Bit sidecar that reads the audit log and forwards it (e.g. to stdout or to a remote backend). You can provide a custom config via `extraVolumes` and a `ConfigMap`.

**values snippet:**

```yaml
serviceapi:
  auditLogs:
    enable: true
    loglevel: info
  extraVolumes:
    - name: fluentbit-config
      configMap:
        name: reportportal-fluentbit-audit
  extraContainers:
    - name: fluentbit
      image: fluent/fluent-bit:2.2
      volumeMounts:
        - name: audit-log-volume
          mountPath: /var/log
        - name: fluentbit-config
          mountPath: /fluent-bit/etc
          readOnly: true
      resources:
        requests:
          cpu: 10m
          memory: 25Mi
        limits:
          cpu: 100m
          memory: 128Mi
```

Create a `ConfigMap` with your Fluent Bit config (e.g. `fluent-bit.conf` and any parsers). Example that tails the audit log and prints to stdout:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: reportportal-fluentbit-audit
data:
  fluent-bit.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/reportportal/audit.log
        Refresh_Interval  5
        Skip_Long_Lines   On
        Tag               reportportal.audit
    [OUTPUT]
        Name              stdout
        Match             *
```

Install or upgrade the chart with the ConfigMap present and the values above; the API pod will run the Fluent Bit sidecar and it will read from the shared audit log volume.

### Example: Simple tail sidecar (for testing)

For a quick test (e.g. to confirm the volume and path), you can add a minimal sidecar that tails the file to stdout:

```yaml
serviceapi:
  auditLogs:
    enable: true
  extraContainers:
    - name: audit-tail
      image: busybox:latest
      command: ["/bin/sh", "-c"]
      args:
        - while true; do if [ -e /var/log/reportportal/audit.log ]; then tail -f /var/log/reportportal/audit.log; else sleep 5; fi; done
      volumeMounts:
        - name: audit-log-volume
          mountPath: /var/log
      resources:
        requests: { cpu: 10m, memory: 10Mi }
        limits:   { cpu: 50m, memory: 32Mi }
```

View audit lines from the sidecar:

```bash
kubectl logs -l component=<release>-reportportal-api -c audit-tail -n <namespace> -f
```

## Using extra init containers

Init containers run to completion before the main containers start. They are not suitable for **continuous** log streaming. You can use `serviceapi.extraInitContainers` for one-off tasks (e.g. prepare directories or copy a bootstrap file). For ongoing audit log collection, use a **sidecar** via `serviceapi.extraContainers` as shown above.

## Summary

| Goal                         | Approach                                                                 |
|-----------------------------|--------------------------------------------------------------------------|
| Enable audit logging        | `serviceapi.auditLogs.enable: true`                                      |
| Ship logs to a backend      | Add a sidecar in `serviceapi.extraContainers` that mounts `audit-log-volume` at `/var/log` and reads `/var/log/reportportal/audit.log`. |
| Sidecar needs config        | Add `serviceapi.extraVolumes` (e.g. ConfigMap) and mount it in the sidecar. |
| One-off setup (no streaming)| Use `serviceapi.extraInitContainers` if needed; for streaming use extraContainers. |
