{{/* Required Cloudsmith coordinates (fed from Terraform outputs). */}}
{{- define "cr.org" -}}
{{- required "cloudsmith.org is required (terraform output org_slug)" .Values.cloudsmith.org -}}
{{- end -}}

{{- define "cr.repo" -}}
{{- required "cloudsmith.repo is required (terraform output repository_slug)" .Values.cloudsmith.repo -}}
{{- end -}}

{{- define "cr.serviceSlug" -}}
{{- required "cloudsmith.serviceSlug is required (terraform output shared_service_slug)" .Values.cloudsmith.serviceSlug -}}
{{- end -}}

{{/* docker.cloudsmith.io/<org>/<repo>/ — trailing slash on purpose. */}}
{{- define "cr.registryPrefix" -}}
{{- .Values.cloudsmith.registryHost -}}/{{- include "cr.org" . -}}/{{- include "cr.repo" . -}}/
{{- end -}}
