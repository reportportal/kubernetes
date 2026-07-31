 <!-- Write a documentration on how to use DHI with ReportPortal. Steps:
1. Create a ImagePullSecret and set into global values
2. Change images for rabbitmq and postgres to dhi 
https://hub.docker.com/hardened-images/catalog/dhi/postgres
dhi.io/postgres:18-alpine3.23
https://hub.docker.com/hardened-images/catalog/dhi/rabbitmq/guides
dhi.io/rabbitmq:4
Uncomment important values and useHardenedImage=true for postgres -->

```yaml
## @section External dependencies installation configuration
##
## @param postgresql External PostgreSQL Helm Chart as dependency
## Set postgresql.install to `false` if using a Cloud/On-Premise managed PostgreSQL
##
postgresql:
  install: true
  ## @param postgresql.image.registry PostgreSQL image registry
  ## Override to use a hardened/distroless image (e.g. `dhi.io` for Docker Hardened Images).
  ##
  image:
    registry: dhi.io
    repository: postgres
    ## @param postgresql.image.tag PostgreSQL image tag
    ## The `18-alpine3.23` tag of `dhi.io/postgres` ships a hardened PostgreSQL 18 build.
    ##
    tag: "18-alpine3.23"
    ## @param postgresql.image.useHardenedImage Set to true when using hardened images
    ## (e.g., DHI) that use a different PGDATA path. Required so the subchart
    ## mounts `/var/lib/postgresql/data` instead of the upstream default.
    ##
    useHardenedImage: true
  args: []
  ## DHI PostgreSQL runs the `postgres` user as UID/GID 70. The subchart's default
  ## `runAsUser: 999` would fail to write to the data volume, so override to match
  ## the image.
  ##
  containerSecurityContext:
    runAsUser: 70
    runAsGroup: 70
    runAsNonRoot: true
  podSecurityContext:
    fsGroup: 70
  auth:
    username: *dbuser
    password: *dbpassword
    database: *dbname
  service:
    port: *dbport
```