{{- define "base.cronReleaseName" -}}
  {{- $name := printf "%s" .Values.instance_id }}
  {{- default .Values.instance_id $name }}
{{- end }}