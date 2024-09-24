{{- define "base.image" }}
{{- $registry := default .Values.global.image.registry .Values.registry }}
{{- $image := printf "%s/%s" $registry .Values.repository}}
{{- if .Values.digest }}
{{- printf "%s@%s" $image .Values.digest }}
{{- else }}
{{- $tag := default "latest" .Values.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}
