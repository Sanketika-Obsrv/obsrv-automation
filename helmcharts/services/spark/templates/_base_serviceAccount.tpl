{{- define "base.connectorServiceaccountname" -}}
  {{- $name := printf "%s-%s" .Chart.Name "cron-sa" }}
  {{- default $name .Values.connectors.serviceAccount.name }}
{{- end }}