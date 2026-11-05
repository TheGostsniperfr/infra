# Monitoring: steps outside Git

kube-prometheus-stack is synced by Argo CD. The steps below change the nodes themselves
(kubeadm static pods, a kubeadm DaemonSet), so they are done by hand, in this order.

## 1. Expose etcd metrics on the node IP

kubeadm makes etcd serve `/metrics` on `127.0.0.1:2381`, which Prometheus cannot reach.
The metrics port is plain HTTP and serves metrics only (no keys, no API).

On `master-node`, edit the static pod manifest. The kubelet restarts etcd by itself:

```bash
sudo sed -i 's|--listen-metrics-urls=http://127.0.0.1:2381|--listen-metrics-urls=http://127.0.0.1:2381,http://192.168.1.73:2381|' \
  /etc/kubernetes/manifests/etcd.yaml
# wait for etcd and the API server to come back
kubectl -n kube-system get pod etcd-master-node -w
curl -s http://192.168.1.73:2381/metrics | grep -m1 etcd_server_has_leader
```

Keep the same flag in the kubeadm ClusterConfiguration so an upgrade does not revert it:

```bash
kubectl -n kube-system get cm kubeadm-config -o yaml   # etcd.local.extraArgs
```

Done on 2026-11-05: manifest and `kubeadm-config` updated, the previous manifest is in
`/root/etcd.yaml.bak-20261105` on master-node. Without this flag the `kubeEtcd` scrape in
`values.yaml` raises TargetDown and etcdMembersDown.

## 2. Remove kube-proxy

Done on 2026-11-05 after #77: DaemonSet and ConfigMap deleted, `KUBE-*` iptables rules
cleaned on the 4 nodes (724 lines each). The rules before cleanup are in
`/root/{iptables,ip6tables}-before-kube-proxy-removal.rules` on each node. The steps below
are kept for a rebuilt node or cluster.

Cilium runs with `kubeProxyReplacement: true`, kube-proxy is a leftover from `kubeadm init`
and programs a second set of iptables rules for the same Services.
Feature: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/

Prerequisite: the Cilium PR that sets `k8sServiceHost`/`k8sServicePort` is merged and every
`cilium` pod has restarted. Without it Cilium reaches the API server through the
`kubernetes` Service, which kube-proxy serves until Cilium is up.

```bash
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system delete cm kube-proxy
# on every node: drop the KUBE-* iptables chains kube-proxy left behind
sudo iptables-save | grep -v KUBE | sudo iptables-restore
# check that Services still answer, from any pod
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep KubeProxyReplacement
```

Tell `kubeadm upgrade` not to bring it back:

```bash
sudo kubeadm upgrade apply <version> --skip-phases=addon/kube-proxy
```
