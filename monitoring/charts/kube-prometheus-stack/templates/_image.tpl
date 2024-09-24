{{- define "base.prometheus.image" }}
{{- $registry := default .Values.global.image.registry .Values.prometheus.prometheusSpec.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.prometheus.prometheusSpec.image.repository}}
{{- if .Values.prometheus.prometheusSpec.image.digest }}
{{- printf "%s@%s" $image .Values.prometheus.prometheusSpec.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.prometheus.prometheusSpec.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}