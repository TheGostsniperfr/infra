# Kyverno Docs

## Policies Examples

A list of simple policies are available here: https://kyverno.io/policies/

## Get Kyverno Reports

#TODO Check is reports are clean ?
#TOOD Check add alert on new report

```bash
kubectl get policyreport -A
```

## Adge effect (e.g., ArgoCD)

Due to Kyverno's [auto-generation rules](https://kyverno.io/docs/policy-types/cluster-policy/autogen/), when we write a rule concerning the deployment of pods, it will be modified to handle all other abstract resources that can deploy pods (e.g., Deployment, DaemonSet, etc.).
The rule is then rewritten by Kyverno and applied. The problem is that ArgoCD will treat this change as a drift and reapply the original rule. This will create an infinite loop between ArgoCD and Kyverno.

Kyverno Documentation for [ArgoCD Users Best Practice](https://kyverno.io/docs/installation/platform-notes/#notes-for-argocd-users)
