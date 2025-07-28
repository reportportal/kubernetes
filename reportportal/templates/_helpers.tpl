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
*/}}
{{- define "reportportal.securityContext" -}}
{{- $serviceContext := .serviceContext -}}
{{- $defaultContext := .Values.global.defaultSecurityContext -}}
{{- if and $defaultContext.enabled $defaultContext -}}
{{- $merged := merge $serviceContext $defaultContext -}}
{{- $mergedWithoutEnabled := omit $merged "enabled" -}}
{{- $mergedWithoutEnabled | toYaml -}}
{{- else -}}
{{- $serviceContext | toYaml -}}
{{- end -}}
{{- end -}}



