{{/*
Base name for every object: the release name, trimmed to the 63-char DNS limit.
*/}}
{{- define "dso202.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels for every object.
*/}}
{{- define "dso202.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: dso202-tasks
app.kubernetes.io/environment: {{ .Values.environment }}
{{- end -}}

{{/*
Selector labels: stable, never change after install. Call with (dict "root" . "tier" "backend").
*/}}
{{- define "dso202.selectorLabels" -}}
app.kubernetes.io/instance: {{ .root.Release.Name }}
tier: {{ .tier }}
{{- end -}}

{{/*
Full image reference. Call with (dict "root" . "name" .Values.backend.image).
*/}}
{{- define "dso202.image" -}}
{{- printf "%s/%s:%s" .root.Values.image.repository .name (default .root.Chart.AppVersion .root.Values.image.tag) -}}
{{- end -}}

{{/*
Object names shared between templates.
*/}}
{{- define "dso202.configName" -}}{{ include "dso202.fullname" . }}-config{{- end -}}
{{- define "dso202.secretName" -}}{{ include "dso202.fullname" . }}-secret{{- end -}}
{{- define "dso202.dbName" -}}{{ include "dso202.fullname" . }}-db{{- end -}}
{{- define "dso202.backendName" -}}{{ include "dso202.fullname" . }}-backend{{- end -}}
{{- define "dso202.frontendName" -}}{{ include "dso202.fullname" . }}-frontend{{- end -}}

{{/*
Pod annotations that force a rollout when the ConfigMap or Secret content changes.
*/}}
{{- define "dso202.checksums" -}}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
{{- end -}}
