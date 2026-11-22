{{- define "deploytrack.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "deploytrack.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "deploytrack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "deploytrack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "deploytrack.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{ include "deploytrack.selectorLabels" . }}
app.kubernetes.io/version: {{ include "deploytrack.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment }}
{{- end -}}

{{- define "deploytrack.tag" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}
