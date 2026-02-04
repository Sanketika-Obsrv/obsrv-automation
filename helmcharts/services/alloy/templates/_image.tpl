{{- define "alloy.image" }}
{{- $registry := default .Values.global.image.registry .Values.registry }}
{{- $repository := default .Values.image.repository .Values.repository }}
{{- $image := printf "%s/%s" $registry $repository }}
{{- if .Values.digest }}
{{- printf "%s@%s" $image .Values.digest }}
{{- else if .Values.tag }}
{{- printf "%s:%s" $image .Values.tag }}
{{- else if .Values.image.tag }}
{{- printf "%s:%s" $image .Values.image.tag }}
{{- else }}
{{- printf "%s:%s" $image .Chart.AppVersion }}
{{- end }}
{{- end }}

{{- define "alloy.configReloader.image" }}
{{- $registry := default .Values.global.image.registry .Values.configReloader.image.registry }}
{{- $repository := .Values.configReloader.image.repository }}
{{- $image := printf "%s/%s" $registry $repository }}
{{- if .Values.configReloader.image.digest }}
{{- printf "%s@%s" $image .Values.configReloader.image.digest }}
{{- else if .Values.configReloader.image.tag }}
{{- printf "%s:%s" $image .Values.configReloader.image.tag }}
{{- else }}
{{- printf "%s:v0.8.0" $image }}
{{- end }}
{{- end }}
