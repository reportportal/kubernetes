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



