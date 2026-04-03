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
Returns: minio, seaweedfs, s3, s3-compatible, aws-s3, or filesystem
*/}}
{{- define "reportportal.storageType" -}}
{{- $storageType := .Values.storage.type | default "minio" -}}
{{- if not (has $storageType (list "seaweedfs" "minio" "s3" "s3-compatible" "aws-s3" "filesystem")) -}}
{{- fail "storage.type must be one of: seaweedfs, minio, s3, s3-compatible, aws-s3, filesystem" -}}
{{- end -}}
{{- $storageType -}}
{{- end -}}

{{/*
Returns the value for the DATASTORE_TYPE environment variable consumed by ReportPortal services.
SeaweedFS exposes a standard S3-compatible API, so it maps to the "minio" JClouds provider
(which handles any S3-compatible endpoint, not just MinIO itself).
*/}}
{{- define "reportportal.datastoreType" -}}
{{- $storageType := include "reportportal.storageType" . -}}
{{- if eq $storageType "seaweedfs" -}}minio
{{- else -}}
{{- $storageType -}}
{{- end -}}
{{- end -}}

{{/*
Returns the full S3 endpoint URL for minio and seaweedfs storage types.
Port is auto-selected based on storage type when storage.port is empty:
  seaweedfs → 8333 (SeaweedFS S3 gateway default)
  minio     → 9000 (MinIO API default)
Override storage.endpoint to point at an external or custom service.
*/}}
{{- define "reportportal.storageEndpoint" -}}
{{- $storageType := include "reportportal.storageType" . -}}
{{- $scheme := ternary "https" "http" .Values.storage.ssl -}}
{{- if eq $storageType "minio" -}}
  {{- $port := .Values.storage.port | default 9000 -}}
  {{- $host := .Values.storage.endpoint | default (printf "%s-minio.%s.svc.cluster.local" .Release.Name .Release.Namespace) -}}
  {{- printf "%s://%s:%v" $scheme $host $port -}}
{{- else if eq $storageType "seaweedfs" -}}
  {{- $port := .Values.storage.port | default 8333 -}}
  {{- $host := .Values.storage.endpoint | default (printf "%s-seaweedfs-all-in-one.%s.svc.cluster.local" .Release.Name .Release.Namespace) -}}
  {{- printf "%s://%s:%v" $scheme $host $port -}}
{{- end -}}
{{- end -}}



