{{- define "base.prometheus-node-exporter.image" }}
{{- $registry := default .Values.global.image.registry .Values.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.image.repository}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $image .Values.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}