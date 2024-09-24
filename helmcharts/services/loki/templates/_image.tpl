{{- define "base.loki.gatewayImage" }}
{{- $registry := default .Values.global.image.registry .Values.gateway.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.gateway.image.repository}}
{{- if .Values.gateway.digest }}
{{- printf "%s@%s" $image .Values.gateway.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.gateway.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.loki.image" }}
{{- $registry := default .Values.global.image.registry .Values.singleBinary.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.singleBinary.image.repository}}
{{- if .Values.singleBinary.image.digest }}
{{- printf "%s@%s" $image .Values.singleBinary.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.singleBinary.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}