{{/* vim: set filetype=mustache: */}}
{{/*
Generate labels
*/}}
{{- define "labels" }}
heritage: {{ $.Release.Service | quote }}
release: {{ $.Release.Name | quote }}
chart: "{{ $.Chart.Name }}-{{ $.Chart.Version }}"
app: {{ $.Release.Name | quote }}
{{- end -}}

{{- define "nodeSelector" }}
{{- if and .Values.nodeSelector.enabled -}}
nodeSelector:
{{ toYaml .Values.nodeSelector.selector | indent 2 -}}
{{- end -}}
{{- end -}}