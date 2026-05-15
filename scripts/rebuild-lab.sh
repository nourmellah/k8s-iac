#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/reset-lab.sh
vagrant up
cd ansible

extra_args=()
if [ -n "${ANSIBLE_PLAYBOOK_ARGS:-}" ]; then
  # Allows: ANSIBLE_PLAYBOOK_ARGS="--ask-vault-pass" scripts/rebuild-lab.sh
  # shellcheck disable=SC2206
  extra_args=(${ANSIBLE_PLAYBOOK_ARGS})
fi

ansible-playbook "${extra_args[@]}" playbooks/site.yml
