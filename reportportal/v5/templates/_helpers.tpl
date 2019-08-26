{{/* vim: set filetype=mustache: */}}
{{/*
Generate labels
*/}}
{{- define "labels" }}
heritage: {{ $.Release.Service | quote }}
release: {{ $.Release.Name | quote }}
chart: "{{ $.Chart.Name }}-{{ $.Chart.Version }}"
app: {{ $.Chart.Name | quote }}
{{- end -}}

{{- define "nodeSelector" }}
{{- if and .Values.nodeSelector.enabled -}}
nodeSelector:
{{ toYaml .Values.nodeSelector.selector | indent 2 -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "reportportal.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccount.create -}}
    {{ default "reportportal" .Values.rbac.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.rbac.serviceAccount.name }}
{{- end -}}
{{- end -}}