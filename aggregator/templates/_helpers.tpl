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
