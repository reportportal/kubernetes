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
Get storage type with default "minio" and validation.
Returns: minio, s3, s3-compatible, aws-s3, or filesystem
*/}}
{{- define "reportportal.storageType" -}}
{{- $storageType := .Values.storage.type | default "minio" -}}
{{- if not (has $storageType (list "minio" "s3" "s3-compatible" "aws-s3" "filesystem")) -}}
{{- fail "storage.type must be one of: minio, s3, s3-compatible, aws-s3, filesystem" -}}
{{- end -}}
{{- $storageType -}}
{{- end -}}

{{/*
Analyzer storage subpath, normalised to have no leading or trailing slash.
Accepts both "analyzer" and "/analyzer" style values so that overrides from
older chart versions (which shipped with a leading slash) continue to work.
*/}}
{{- define "reportportal.analyzerSubpath" -}}
{{- .Values.storage.volume.analyzerPath | default "analyzer" | trimPrefix "/" | trimSuffix "/" -}}
{{- end -}}

{{/*
Returns the value for the DATASTORE_TYPE environment variable consumed by ReportPortal services.
All storage types pass through unchanged (minio, s3, s3-compatible, aws-s3, filesystem).
*/}}
{{- define "reportportal.datastoreType" -}}
{{- include "reportportal.storageType" . -}}
{{- end -}}

{{/*
Returns the DATASTORE_TYPE value for the auto-analyzer service only.
The analyzer uses a different provider mapping from other services:
  - filesystem    → "filesystem"     (pass through)
  - minio         → "minio"          (pass through)
  - s3            → "s3"             (pass through)
  - s3-compatible → "minio"          (S3-compatible, uses the same minio provider)
  - aws-s3        → "s3"             (analyzer expects "s3", not "aws-s3")
*/}}
{{- define "reportportal.analyzerDatastoreType" -}}
{{- $storageType := include "reportportal.storageType" . -}}
{{- if eq $storageType "s3-compatible" -}}minio
{{- else if eq $storageType "aws-s3" -}}s3
{{- else -}}
{{- $storageType -}}
{{- end -}}
{{- end -}}

{{/*
Returns the full S3 endpoint URL for minio and s3-compatible storage types.
Port is auto-selected based on storage type when storage.port is empty:
  minio / s3-compatible → 9000 (MinIO API default)
Override storage.endpoint to point at an external or custom service.
*/}}
{{- define "reportportal.storageEndpoint" -}}
{{- $storageType := include "reportportal.storageType" . -}}
{{- $scheme := ternary "https" "http" .Values.storage.ssl -}}
{{- if or (eq $storageType "minio") (eq $storageType "s3-compatible") -}}
  {{- $port := .Values.storage.port | default 9000 -}}
  {{- $host := .Values.storage.endpoint | default (printf "%s-minio.%s.svc.%s" .Release.Name .Release.Namespace .Values.global.clusterDomain) -}}
  {{- printf "%s://%s:%v" $scheme $host $port -}}
{{- end -}}
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
Return true when the Test Executions Prime feature should be deployed.
*/}}
{{- define "reportportal.prime.testExecutions.enabled" -}}
{{- if and .Values.prime.enabled .Values.prime.testExecutions.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Return true when the SCIM Bridge Prime feature should be deployed.
*/}}
{{- define "reportportal.prime.scim.enabled" -}}
{{- if and .Values.prime.enabled .Values.prime.scim.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Fully qualified name for a Prime component.
Usage: include "reportportal.prime.fullname" (dict "root" . "suffix" "test-executions")
*/}}
{{- define "reportportal.prime.fullname" -}}
{{- $suffixLen := add (len .suffix) 1 -}}
{{- $maxRootLen := sub 63 $suffixLen | int -}}
{{- printf "%s-%s" (include "reportportal.fullname" .root | trunc $maxRootLen | trimSuffix "-") .suffix -}}
{{- end -}}

{{/*
Image reference for a Prime component (nested under .Values.prime.<componentKey>).
Usage: include "reportportal.prime.image" (dict "root" . "componentKey" "testExecutions")
Fails when repository or tag is empty and the component is enabled.
*/}}
{{- define "reportportal.prime.image" -}}
{{- $root := .root -}}
{{- $comp := index $root.Values.prime .componentKey -}}
{{- $repo := required (printf "prime.%s.image.repository is required when Prime %s is enabled (paid subscriber image)" .componentKey .componentKey) $comp.image.repository -}}
{{- $tag := required (printf "prime.%s.image.tag is required when Prime %s is enabled (paid subscriber image)" .componentKey .componentKey) $comp.image.tag -}}
{{- $globalRegistry := $root.Values.global.imageRegistry -}}
{{- if $globalRegistry -}}
{{- printf "%s/%s:%s" $globalRegistry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
Merged imagePullSecrets for a Prime component (global + component-level).
Usage: include "reportportal.prime.imagePullSecrets" (dict "root" . "componentKey" "testExecutions")
*/}}
{{- define "reportportal.prime.imagePullSecrets" -}}
{{- $root := .root -}}
{{- $comp := index $root.Values.prime .componentKey -}}
{{- $secrets := concat ($root.Values.global.imagePullSecrets | default list) ($comp.image.pullSecrets | default list) -}}
{{- if $secrets -}}
{{- toYaml $secrets -}}
{{- end -}}
{{- end -}}

{{/*
SCIM health-check path (base path + healthPath).
*/}}
{{- define "reportportal.prime.scim.healthUrlPath" -}}
{{- $base := .Values.prime.scim.path | default "/scim/v2" | trimSuffix "/" -}}
{{- $health := .Values.prime.scim.healthPath | default "/ServiceProviderConfig" -}}
{{- if not (hasPrefix "/" $health) -}}
{{- $health = printf "/%s" $health -}}
{{- end -}}
{{- printf "%s%s" $base $health -}}
{{- end -}}


