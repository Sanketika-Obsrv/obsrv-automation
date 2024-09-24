{{- define "base.testFramework.image" }}
{{- $registry := default .Values.global.image.registry .Values.testFramework.registry }}
{{- $image := printf "%s/%s" $registry .Values.testFramework.repository}}
{{- if .Values.testFramework.digest }}
{{- printf "%s@%s" $image .Values.testFramework.digest }}
{{- else }}
{{- $tag := default "latest" .Values.testFramework.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.grafana.image" }}
{{- $registry := default .Values.global.image.registry .Values.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.image.repository}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $image .Values.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.downloadDashboards.image" }}
{{- $registry := default .Values.global.image.registry .Values.downloadDashboardsImage.registry }}
{{- $image := printf "%s/%s" $registry .Values.downloadDashboardsImage.repository}}
{{- if .Values.downloadDashboardsImage.digest }}
{{- printf "%s@%s" $image .Values.downloadDashboardsImage.digest }}
{{- else }}
{{- $tag := default "latest" .Values.downloadDashboardsImage.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.initChownData.image" }}
{{- $registry := default .Values.global.image.registry .Values.initChownData.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.initChownData.image.repository}}
{{- if .Values.initChownData.image.digest }}
{{- printf "%s@%s" $image .Values.initChownData.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.initChownData.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.sidecar.image" }}
{{- $registry := default .Values.global.image.registry .Values.sidecar.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.sidecar.image.repository}}
{{- if .Values.sidecar.image.digest }}
{{- printf "%s@%s" $image .Values.sidecar.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.sidecar.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}

{{- define "base.imageRenderer.image" }}
{{- $registry := default .Values.global.image.registry .Values.imageRenderer.image.registry }}
{{- $image := printf "%s/%s" $registry .Values.imageRenderer.image.repository}}
{{- if .Values.imageRenderer.image.digest }}
{{- printf "%s@%s" $image .Values.imageRenderer.image.digest }}
{{- else }}
{{- $tag := default "latest" .Values.imageRenderer.image.tag }}
{{- printf "%s:%s" $image $tag }}
{{- end }}
{{- end }}