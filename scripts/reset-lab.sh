#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VM_NAMES=(
  iac-k8s-cp1
  iac-k8s-worker-app-1
  iac-k8s-worker-app-2
  iac-k8s-worker-ci
)

echo "[reset] stopping Vagrant-managed VMs if Vagrant still knows them..."
vagrant destroy -f || true

echo "[reset] removing local Vagrant state..."
rm -rf .vagrant

echo "[reset] removing stale VirtualBox registrations and folders..."
for vm in "${VM_NAMES[@]}"; do
  VBoxManage controlvm "$vm" poweroff >/dev/null 2>&1 || true
  VBoxManage unregistervm "$vm" --delete >/dev/null 2>&1 || true
  rm -rf "$HOME/VirtualBox VMs/$vm"
done

rm -rf "$HOME/VirtualBox VMs"/temp_clone_*
vagrant global-status --prune || true

echo "[reset] clean. Run: vagrant up && cd ansible && ansible-playbook playbooks/site.yml"
