{{- define "app.name" -}}
{{- required "platform.component is required" .Values.platform.component -}}
{{- end -}}

{{- define "app.vaultRole" -}}
apps-{{ .Values.platform.team }}-{{ .Values.platform.app }}
{{- end -}}
