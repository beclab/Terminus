{{/* vim: set filetype=mustache: */}}

{{/*
Create argo workflows server name and version as used by the chart label.
*/}}
{{- define "argo-workflows.server.fullname-bak" -}}
{{- printf "%s-%s" (include "argo-workflows.fullname" .) .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "argo-workflows.server.fullname" -}}
argoworkflows
{{- end -}}

{{/*
Create controller name and version as used by the chart label.
*/}}
{{- define "argo-workflows.controller.fullname" -}}
{{- printf "%s-%s" (include "argo-workflows.fullname" .) .Values.controller.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "argo-workflows.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{/*{{- define "argo-workflows.fullname" -}}*/}}
{{/*{{- if .Values.fullnameOverride -}}*/}}
{{/*{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}*/}}
{{/*{{- else -}}*/}}
{{/*{{- $name := default .Chart.Name .Values.nameOverride -}}*/}}
{{/*{{- if contains $name .Release.Name -}}*/}}
{{/*{{- .Release.Name | trunc 63 | trimSuffix "-" -}}*/}}
{{/*{{- else -}}*/}}
{{/*{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}*/}}
{{/*{{- end -}}*/}}
{{/*{{- end -}}*/}}
{{/*{{- end -}}*/}}

{{- define "argo-workflows.fullname" -}}
argoworkflow
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "argo-workflows.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create kubernetes friendly chart version label for the controller.
Examples:
image.tag = v3.4.4
output    = v3.4.4

image.tag = v3.4.4@sha256:d06860f1394a94ac3ff8401126ef32ba28915aa6c3c982c7e607ea0b4dadb696
output    = v3.4.4
*/}}
{{- define "argo-workflows.controller_chart_version_label" -}}
{{- regexReplaceAll "[^a-zA-Z0-9-_.]+" (regexReplaceAll "@sha256:[a-f0-9]+" (default (include "argo-workflows.defaultTag" .) .Values.controller.image.tag) "") "" | trunc 63 | quote -}}
{{- end -}}

{{/*
Create kubernetes friendly chart version label for the server.
Examples:
image.tag = v3.4.4
output    = v3.4.4

image.tag = v3.4.4@sha256:d06860f1394a94ac3ff8401126ef32ba28915aa6c3c982c7e607ea0b4dadb696
output    = v3.4.4
*/}}
{{- define "argo-workflows.server_chart_version_label" -}}
{{- regexReplaceAll "[^a-zA-Z0-9-_.]+" (regexReplaceAll "@sha256:[a-f0-9]+" (default (include "argo-workflows.defaultTag" .) .Values.server.image.tag) "") "" | trunc 63 | quote -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "argo-workflows.labels" -}}
helm.sh/chart: {{ include "argo-workflows.chart" .context }}
{{ include "argo-workflows.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: argo-workflows
{{- end }}

{{/*
Selector labels
*/}}
{{- define "argo-workflows.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "argo-workflows.name" .context }}-{{ .name }}
{{ end -}}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the server service account to use
*/}}
{{- define "argo-workflows.serverServiceAccountName" -}}
{{- if .Values.server.serviceAccount.create -}}
    {{ default (include "argo-workflows.server.fullname" .) .Values.server.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.server.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the controller service account to use
*/}}
{{- define "argo-workflows.controllerServiceAccountName" -}}
{{- if .Values.controller.serviceAccount.create -}}
    {{ default (include "argo-workflows.controller.fullname" .) .Values.controller.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.controller.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for ingress
*/}}
{{- define "argo-workflows.ingress.apiVersion" -}}
{{- if semverCompare "<1.14-0" (include "argo-workflows.kubeVersion" $) -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "<1.19-0" (include "argo-workflows.kubeVersion" $) -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the target Kubernetes version
*/}}
{{- define "argo-workflows.kubeVersion" -}}
  {{- default .Capabilities.KubeVersion.Version .Values.kubeVersionOverride }}
{{- end -}}

{{/*
Return the default Argo Workflows app version
*/}}
{{- define "argo-workflows.defaultTag" -}}
  {{- default .Chart.AppVersion .Values.images.tag }}
{{- end -}}

{{/*
Return full image name including or excluding registry based on existence
*/}}
{{- define "argo-workflows.image" -}}
{{- if and .image.registry .image.repository -}}
  {{ .image.registry }}/{{ .image.repository }}
{{- else -}}
  {{ .image.repository }}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for autoscaling
*/}}
{{- define "argo-workflows.apiVersion.autoscaling" -}}
{{- if .Values.apiVersionOverrides.autoscaling -}}
{{- print .Values.apiVersionOverrides.autoscaling -}}
{{- else if semverCompare "<1.23-0" (include "argo-workflows.kubeVersion" .) -}}
{{- print "autoscaling/v2beta1" -}}
{{- else -}}
{{- print "autoscaling/v2" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for GKE resources
*/}}
{{- define "argo-workflows.apiVersions.cloudgoogle" -}}
{{- if .Values.apiVersionOverrides.cloudgoogle -}}
{{- print .Values.apiVersionOverrides.cloudgoogle -}}
{{- else if .Capabilities.APIVersions.Has "cloud.google.com/v1" -}}
{{- print "cloud.google.com/v1" -}}
{{- else -}}
{{- print "cloud.google.com/v1beta1" -}}
{{- end -}}
{{- end -}}
