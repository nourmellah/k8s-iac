#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ssh_cmd() {
  local vm="$1"
  shift
  vagrant ssh "$vm" -c "$*"
}

http_code() {
  local url="$1"
  curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$url" || true
}

ok() { echo "[OK] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

echo "== VM reachability =="
for vm in cp1 worker-app-1 worker-app-2 worker-ci; do
  ssh_cmd "$vm" "hostname" >/dev/null || fail "$vm is not reachable by vagrant ssh"
  ok "$vm reachable"
done

echo
echo "== Service endpoints =="
[[ "$(http_code http://192.168.56.13:30082/)" =~ ^(200|301|302|303)$ ]] || fail "Gitea is not reachable on Tools VM"
ok "Gitea reachable: http://192.168.56.13:30082"
[[ "$(http_code http://192.168.56.13:30083/)" =~ ^(200|301|302|303)$ ]] || fail "Nexus UI is not reachable on Tools VM"
ok "Nexus UI reachable: http://192.168.56.13:30083"
[[ "$(http_code http://192.168.56.13:30084/v2/)" =~ ^(200|401)$ ]] || fail "Nexus Docker Registry is not reachable on Tools VM"
ok "Nexus Docker Registry reachable: 192.168.56.13:30084"
[[ "$(http_code http://192.168.56.10:30080/login)" =~ ^(200|403)$ ]] || fail "Jenkins is not reachable on cp1"
ok "Jenkins reachable: http://192.168.56.10:30080"

echo
echo "== Kubernetes topology =="
ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide"
node_count="$(ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes --no-headers | wc -l" | tr -dc '0-9')"
[[ "$node_count" == "3" ]] || fail "Expected exactly 3 Kubernetes nodes, got $node_count"
if ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get node worker-ci" >/dev/null 2>&1; then
  fail "worker-ci/tools VM must not be part of the K3s cluster"
fi
ok "K3s cluster contains cp1 + 2 workers only"

jenkins_node="$(ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n jenkins get pod jenkins-0 -o jsonpath='{.spec.nodeName}'" | tr -d '\r')"
[[ "$jenkins_node" == "cp1" ]] || fail "Jenkins is not scheduled on cp1; current node: $jenkins_node"
ok "Jenkins pod runs on cp1"

echo
echo "== NFS and database =="
ssh_cmd worker-app-1 "showmount -e 192.168.56.13" | grep -q '/srv/nfs/mysql' || fail "NFS export /srv/nfs/mysql not visible from worker-app-1"
ok "NFS export visible from worker-app-1"
ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n database get pvc mysql-nfs-pvc" >/dev/null || fail "MySQL PVC missing"
ok "MySQL PVC exists"
ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n database rollout status statefulset/mysql --timeout=30s" >/dev/null || fail "MySQL is not ready"
ok "MySQL StatefulSet ready"

echo
echo "== Application =="
ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n hello rollout status deployment/backend --timeout=30s" >/dev/null || fail "Backend not ready"
ok "Backend deployment ready"
ssh_cmd cp1 "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n hello rollout status deployment/frontend --timeout=30s" >/dev/null || fail "Frontend not ready"
ok "Frontend deployment ready"
[[ "$(http_code http://192.168.56.10:30081/)" == "200" ]] || fail "Frontend NodePort is not reachable"
ok "Frontend reachable: http://192.168.56.10:30081"

curl -fsS http://192.168.56.10:30081/api/status | grep -q '"reachable":true' || fail "Backend API cannot confirm MySQL connectivity"
ok "Frontend -> backend -> MySQL path works"

echo
echo "Lab verification succeeded."
