{{/* {{- include "base.image.flink" dict ("context" $ "scope" $jobData) }} */}}
{{- define "base.image.flink" }}
{{- $context := .context }}
{{- $scope := .scope }}
{{- with $scope }}
{{- $registry := default $context.Values.global.image.registry .registry }}
{{- $image := printf "%s/%s" $registry .repository}}
{{- if .digest }}
{{- printf "%s@%s" $image .digest }}
{{- else }}
{{- $tag := default "latest" .tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}
{{- end }}
