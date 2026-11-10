{{/* Namespace and service account of the team's agent (chart gitlab-agent, release gitlab-agent-<team>) */}}
{{- define "platform-team.agent" -}}
{{- required "team is required" .Values.team | printf "gitlab-agent-%s" -}}
{{- end -}}
