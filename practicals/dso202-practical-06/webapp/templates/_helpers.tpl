{{/*
_helpers.tpl - named templates shared by every file in templates/.
*/}}

{{/* webapp.name: the chart name, or nameOverride when set. */}}
{{- define "webapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* webapp.fullname: base name of every object, max 63 characters. */}}
{{- define "webapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* webapp.chart: "<name>-<version>" for the helm.sh/chart label. */}}
{{- define "webapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* webapp.selectorLabels: must NEVER change after first install. */}}
{{- define "webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* webapp.environment: page.environment, else global.environment, else fail. */}}
{{- define "webapp.environment" -}}
{{- required "page.environment must be set (dev, staging or prod)" (.Values.page.environment | default .Values.global.environment) }}
{{- end }}

{{/* webapp.labels: the full recommended label set for every object. */}}
{{- define "webapp.labels" -}}
helm.sh/chart: {{ include "webapp.chart" . }}
{{ include "webapp.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
dso202/environment: {{ include "webapp.environment" . | quote }}
{{- end }}
