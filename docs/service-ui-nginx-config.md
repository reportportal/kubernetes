# Additional Nginx Server Configuration for Service UI

The `service-ui` image can load optional server-level Nginx snippets from
`/etc/nginx/extra-conf.d/*.conf`. If the directory is empty, the image uses only
its built-in configuration.

The snippets are included inside the existing `server` block. They may contain
directives such as `location`, `set`, and `proxy_set_header`, but must not
contain an `http` or `server` block.

## Enable via chart values

Set `serviceui.extraNginxConfig.enabled` to `true` and define the snippets under
`serviceui.extraNginxConfig.config`. Each key becomes a file in the mounted
directory, so the key must end with `.conf`:

```yaml
serviceui:
  extraNginxConfig:
    enabled: true
    config:
      deployment-info.conf: |
        location = /deployment-info {
            default_type text/plain;
            return 200 "service-ui";
        }
```

The chart renders a ConfigMap named `<release>-reportportal-ui-nginx`, mounts it
read-only at `/etc/nginx/extra-conf.d`, and sets the `EXTRA_NGINX_CONFIG`
environment variable to `/etc/nginx/extra-conf.d/*.conf`. Mounting the ConfigMap
at this dedicated path does not replace the image's built-in Nginx
configuration.

The mount path is fixed by the image contract and is not configurable: mounting
elsewhere would either be ignored by Nginx or shadow the built-in configuration
and break the UI. If you need a file somewhere else in the container, use
`serviceui.extraVolumes` and `serviceui.extraVolumeMounts` instead.

A `checksum/nginx-config` pod annotation is added so that changing the snippets
restarts the UI pods on `helm upgrade`.

## Use an existing ConfigMap

To manage the snippets outside the chart, point the chart at an existing
ConfigMap. The `config` values are ignored in that case:

```yaml
serviceui:
  extraNginxConfig:
    enabled: true
    existingConfigMap: service-ui-nginx-extra
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-ui-nginx-extra
data:
  deployment-info.conf: |
    location = /deployment-info {
        default_type text/plain;
        return 200 "service-ui";
    }
```

Note that the chart does not track changes of an externally managed ConfigMap,
so roll the UI deployment yourself after editing it:

```bash
kubectl rollout restart deployment/<release>-reportportal-ui
```

## Security considerations

Treat proxy authentication headers as a security boundary. Only set a trusted
`X-WEBAUTH-USER` after validating the application session, for example with
Nginx `auth_request`. Clear an incoming browser `Authorization` header unless
the upstream is explicitly intended to receive it. Bearer tokens are secrets:
store them in a Kubernetes Secret, not a ConfigMap. Mounted snippets are loaded
directly and are not processed by `envsubst`, so secret-to-header rendering
requires a separate controlled mechanism or authentication proxy.
