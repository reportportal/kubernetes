{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "reportportal.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "reportportal.fullname" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.global.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "reportportal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate labels
*/}}
{{- define "labels" }}
app.kubernetes.io/name: {{ include "reportportal.name" . }}
app.kubernetes.io/instance: {{ $.Release.Name }}
app.kubernetes.io/version: {{ $.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $.Release.Service }}
helm.sh/chart: {{ include "reportportal.chart" . }}
heritage: {{ $.Release.Service | quote }}
release: {{ $.Release.Name | quote }}
chart: {{ include "reportportal.chart" . }}
app: {{ $.Chart.Name | quote }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "reportportal.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create -}}
    {{ default "reportportal" .Values.global.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.global.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create image name
*/}}
{{- define "reportportal.image" -}}
{{- $service := .service -}}
{{- $globalRegistry := .Values.global.imageRegistry -}}
{{- $imageRepository := index .Values $service "image" "repository" -}}
{{- $imageTag := index .Values $service "image" "tag" -}}
{{- if $globalRegistry }}
{{- printf "%s/%s:%s" $globalRegistry $imageRepository $imageTag -}}
{{- else -}}
{{- printf "%s:%s" $imageRepository $imageTag -}}
{{- end -}}
{{- end -}}

{{/*
Merge default security context with service-specific security context
Global context overrides service-specific context
*/}}
{{- define "reportportal.securityContext" -}}
{{- $serviceContext := .serviceContext -}}
{{- $defaultContext := .Values.global.securityContext -}}
{{- if and (not (empty $defaultContext)) (not (kindIs "bool" $defaultContext)) -}}
{{- $merged := merge $defaultContext $serviceContext -}}
{{- $merged | toYaml -}}
{{- else -}}
{{- $serviceContext | toYaml -}}
{{- end -}}
{{- end -}}

{{/*
Resolve resources for built-in wait init containers.
Non-empty service-specific resources take precedence; otherwise use
global.initContainerResources.
*/}}
{{- define "reportportal.initContainerResources" -}}
{{- $serviceResources := .serviceContext -}}
{{- if not (empty $serviceResources) -}}
{{- $serviceResources | toYaml -}}
{{- else -}}
{{- .Values.global.initContainerResources | toYaml -}}
{{- end -}}
{{- end -}}

{{/*
Directory the additional Nginx snippets are mounted to. Fixed by the service-ui
image, which includes /etc/nginx/extra-conf.d/*.conf into its server block.
Mounting anywhere else would either be ignored or shadow the built-in config.
*/}}
{{- define "reportportal.ui.nginxConfigMountPath" -}}
/etc/nginx/extra-conf.d
{{- end -}}

{{/*
Name of the ConfigMap holding the additional Nginx snippets for the UI service.
*/}}
{{- define "reportportal.ui.nginxConfigMapName" -}}
{{- if .Values.serviceui.extraNginxConfig.existingConfigMap -}}
{{- .Values.serviceui.extraNginxConfig.existingConfigMap -}}
{{- else -}}
{{- printf "%s-ui-nginx" (include "reportportal.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Get storage type with default "s3-compatible" and validation.
Returns: s3-compatible, aws-s3, or filesystem.

Legacy values "minio" and "s3" are rejected — OpenDAL-based services
(service-api, service-jobs, service-auto-analyzer) only accept the types above.
Use "s3-compatible" for any S3 API server (SeaweedFS, MinIO, Ceph RGW, ...)
and "aws-s3" for Amazon S3.
*/}}
{{- define "reportportal.storageType" -}}
{{- $storageType := .Values.storage.type | default "s3-compatible" -}}
{{- if or (eq $storageType "minio") (eq $storageType "s3") -}}
{{- fail (printf "storage.type %q is no longer supported; use \"s3-compatible\" (SeaweedFS, MinIO, Ceph RGW, ...) or \"aws-s3\" (Amazon S3)" $storageType) -}}
{{- end -}}
{{- if not (has $storageType (list "s3-compatible" "aws-s3" "filesystem")) -}}
{{- fail "storage.type must be one of: s3-compatible, aws-s3, filesystem" -}}
{{- end -}}
{{- $storageType -}}
{{- end -}}

{{/*
Analyzer storage subpath, normalised to have no leading or trailing slash.
Accepts both "analyzer" and "/analyzer" style values so that overrides from
older chart versions (which shipped with a leading slash) continue to work.
*/}}
{{- define "reportportal.analyzerSubpath" -}}
{{- .Values.storage.volume.analyzerPath | default "analyzer" | replace "\\" "/" | trimAll "/" | default "analyzer" -}}
{{- end -}}

{{/*
Returns the value for the DATASTORE_TYPE environment variable consumed by
ReportPortal services (api, jobs, analyzer). Passes storage.type through unchanged.
*/}}
{{- define "reportportal.datastoreType" -}}
{{- include "reportportal.storageType" . -}}
{{- end -}}

{{/*
Fully qualified name of the bundled SeaweedFS release (mirrors seaweedfs.fullname
when the chart is installed as a subchart named "seaweedfs").
*/}}
{{- define "reportportal.seaweedfs.fullname" -}}
{{- if (.Values.seaweedfs).fullnameOverride -}}
{{- .Values.seaweedfs.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "seaweedfs" (.Values.seaweedfs).nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Returns the full S3 endpoint URL for storage.type=s3-compatible.

Rules:
  1. storage.endpoint is a host name only (no scheme, no port). The scheme comes
     from storage.ssl; :storage.port is appended only when storage.port is set.
     A value starting with http:// or https:// is rejected to avoid conflicting
     with storage.ssl.
  2. When storage.endpoint is empty and seaweedfs.install=true, point at the
     bundled single-node SeaweedFS (all-in-one service, port 8333).
  3. Otherwise fail — an endpoint is required for external S3-compatible storage.
*/}}
{{- define "reportportal.storageEndpoint" -}}
{{- $endpoint := .Values.storage.endpoint | default "" | toString -}}
{{- if or (hasPrefix "http://" $endpoint) (hasPrefix "https://" $endpoint) -}}
{{- fail (printf "storage.endpoint must be a host name without scheme (got %q); use storage.ssl for http/https and storage.port for the port" $endpoint) -}}
{{- else if $endpoint -}}
{{- $scheme := ternary "https" "http" .Values.storage.ssl -}}
{{- if .Values.storage.port -}}
{{- printf "%s://%s:%v" $scheme $endpoint .Values.storage.port -}}
{{- else -}}
{{- printf "%s://%s" $scheme $endpoint -}}
{{- end -}}
{{- else if (.Values.seaweedfs).install -}}
{{- $scheme := ternary "https" "http" .Values.storage.ssl -}}
{{- $fullname := include "reportportal.seaweedfs.fullname" . -}}
{{- $allInOne := (.Values.seaweedfs).allInOne | default dict -}}
{{- $port := .Values.storage.port | default (($allInOne.s3).port) | default 8333 -}}
{{- printf "%s://%s-all-in-one.%s.svc.%s:%v" $scheme $fullname .Release.Namespace .Values.global.clusterDomain $port -}}
{{- else -}}
{{- fail "storage.endpoint is required when storage.type is s3-compatible and seaweedfs.install is false" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the storage region for DATASTORE_REGION.
Maps legacy "us-standard" to "us-east-1".
Required for aws-s3; optional for s3-compatible (services default to us-east-1).
*/}}
{{- define "reportportal.storageRegion" -}}
{{- $storageType := include "reportportal.storageType" . -}}
{{- $region := .Values.storage.region | default "" | toString -}}
{{- if eq $region "us-standard" -}}
{{- $region = "us-east-1" -}}
{{- end -}}
{{- if and (eq $storageType "aws-s3") (eq $region "") -}}
{{- fail "storage.region is required when storage.type is aws-s3" -}}
{{- end -}}
{{- $region -}}
{{- end -}}

{{/*
Shared DATASTORE_* environment variables for object storage
(s3-compatible and aws-s3). Render with | nindent N in service templates.

Emits: DATASTORE_TYPE, DATASTORE_ENDPOINT (s3-compatible only),
DATASTORE_REGION (when set), DATASTORE_ACCESSKEY, DATASTORE_SECRETKEY.
Bucket / feature-flag env vars are service-specific and stay in the templates.
*/}}
{{- define "reportportal.datastoreEnv" -}}
{{- $storageType := include "reportportal.storageType" . -}}
- name: DATASTORE_TYPE
  value: "{{ include "reportportal.datastoreType" . }}"
{{- if eq $storageType "s3-compatible" }}
- name: DATASTORE_ENDPOINT
  value: "{{ include "reportportal.storageEndpoint" . }}"
{{- end }}
{{- $region := include "reportportal.storageRegion" . -}}
{{- if $region }}
- name: DATASTORE_REGION
  value: "{{ $region }}"
{{- end }}
{{- if .Values.storage.secretName }}
- name: DATASTORE_ACCESSKEY
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.storage.secretName }}"
      key: "{{ .Values.storage.accesskeyName }}"
- name: DATASTORE_SECRETKEY
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.storage.secretName }}"
      key: "{{ .Values.storage.secretkeyName }}"
{{- else }}
- name: DATASTORE_ACCESSKEY
  value: "{{ .Values.storage.accesskey }}"
- name: DATASTORE_SECRETKEY
  value: "{{ .Values.storage.secretkey }}"
{{- end }}
{{- end -}}

{{/*
Public MCP URL used for OAuth metadata (MCP_PUBLIC_URL).

Priority:
  1. mcp.oauth.publicUrl when set in an overlay
  2. Ingress host + path when ingress.enable and ingress.hosts are set
  3. Gateway API hostname + path when gatewayAPI.enable and gatewayAPI.hostnames are set
  4. In-cluster MCP Service URL
*/}}
{{- define "reportportal.mcp.publicUrl" -}}
{{- if .Values.mcp.oauth.publicUrl -}}
{{- .Values.mcp.oauth.publicUrl -}}
{{- else -}}
{{- $basePath := "" -}}
{{- $host := "" -}}
{{- $scheme := ternary "https" "http" .Values.k8s.networking.ssl -}}
{{- if and .Values.ingress.enable .Values.ingress.hosts -}}
  {{- if kindIs "slice" .Values.ingress.hosts -}}
    {{- $host = index .Values.ingress.hosts 0 -}}
  {{- else -}}
    {{- $host = .Values.ingress.hosts -}}
  {{- end -}}
  {{- $path := .Values.ingress.path -}}
  {{- if and $path (ne $path "/") -}}
    {{- $basePath = trimSuffix "/" $path -}}
  {{- end -}}
  {{/*
    External Ingress hosts must use https for MCP OAuth (server rejects http except loopback).
    TLS may be terminated outside chart values (controller cert, LB, ssl-redirect), so prefer
    https whenever an Ingress host is used.
  */}}
  {{- $scheme = "https" -}}
{{- else if and .Values.gatewayAPI.enable .Values.gatewayAPI.hostnames -}}
  {{- if kindIs "slice" .Values.gatewayAPI.hostnames -}}
    {{- $host = index .Values.gatewayAPI.hostnames 0 -}}
  {{- else -}}
    {{- $host = .Values.gatewayAPI.hostnames -}}
  {{- end -}}
  {{- $path := .Values.gatewayAPI.path -}}
  {{- if and $path (ne $path "/") -}}
    {{- $basePath = trimSuffix "/" $path -}}
  {{- end -}}
  {{- $scheme = "https" -}}
{{- end -}}
{{- if $host -}}
{{- printf "%s://%s%s/mcp" $scheme $host $basePath -}}
{{- else -}}
{{- printf "%s://%s-mcp.%s.svc.%s:8080/mcp" (ternary "https" "http" .Values.k8s.networking.ssl) (include "reportportal.fullname" .) .Release.Namespace .Values.global.clusterDomain -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return true when the Test Executions Premium feature should be deployed.
*/}}
{{- define "reportportal.premium.testExecutions.enabled" -}}
{{- if .Values.premium.testExecutions.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Return true when the SCIM Bridge Premium feature should be deployed.
*/}}
{{- define "reportportal.premium.scim.enabled" -}}
{{- if .Values.premium.scim.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Fully qualified name for a Premium component.
Usage: include "reportportal.premium.fullname" (dict "root" . "suffix" "test-executions")
*/}}
{{- define "reportportal.premium.fullname" -}}
{{- $suffixLen := add (len .suffix) 1 -}}
{{- $maxRootLen := sub 63 $suffixLen | int -}}
{{- printf "%s-%s" (include "reportportal.fullname" .root | trunc $maxRootLen | trimSuffix "-") .suffix -}}
{{- end -}}

{{/*
Image reference for a Premium component (nested under .Values.premium.<componentKey>).
Usage: include "reportportal.premium.image" (dict "root" . "componentKey" "testExecutions")
Fails when repository or tag is empty and the component is enabled.
*/}}
{{- define "reportportal.premium.image" -}}
{{- $root := .root -}}
{{- $comp := index $root.Values.premium .componentKey -}}
{{- $repo := required (printf "premium.%s.image.repository is required when Premium %s is enabled (paid subscriber image)" .componentKey .componentKey) $comp.image.repository -}}
{{- $tag := required (printf "premium.%s.image.tag is required when Premium %s is enabled (paid subscriber image)" .componentKey .componentKey) $comp.image.tag -}}
{{- $globalRegistry := $root.Values.global.imageRegistry -}}
{{- if $globalRegistry -}}
{{- printf "%s/%s:%s" $globalRegistry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
Merged imagePullSecrets for a Premium component (global + component-level).
Usage: include "reportportal.premium.imagePullSecrets" (dict "root" . "componentKey" "testExecutions")
*/}}
{{- define "reportportal.premium.imagePullSecrets" -}}
{{- $root := .root -}}
{{- $comp := index $root.Values.premium .componentKey -}}
{{- $secrets := concat ($root.Values.global.imagePullSecrets | default list) ($comp.image.pullSecrets | default list) -}}
{{- if $secrets -}}
{{- toYaml $secrets -}}
{{- end -}}
{{- end -}}

{{/*
SCIM health-check path (base path + healthPath).
*/}}
{{- define "reportportal.premium.scim.healthUrlPath" -}}
{{- $base := .Values.premium.scim.path | default "/scim/v2" | trimSuffix "/" -}}
{{- $health := .Values.premium.scim.healthPath | default "/ServiceProviderConfig" -}}
{{- if not (hasPrefix "/" $health) -}}
{{- $health = printf "/%s" $health -}}
{{- end -}}
{{- printf "%s%s" $base $health -}}
{{- end -}}


