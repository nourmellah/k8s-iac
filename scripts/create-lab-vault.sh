#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="$ROOT_DIR/ansible/inventories/dev/group_vars/vault.yml"

if [ -f "$VAULT_FILE" ]; then
  echo "[vault] $VAULT_FILE already exists. Not overwriting."
  exit 1
fi

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    python3 -c 'import secrets; print(secrets.token_hex(32))'
  fi
}

cat > "$VAULT_FILE" <<EOF_VAULT
vault_gitea_admin_password: "giteaadmin123"
vault_jenkins_admin_password: "admin123"
vault_nexus_admin_password: "admin123"
vault_mysql_password: "hello_password_123"
vault_mysql_root_password: "root_password_123"
vault_gitea_webhook_token: "$(rand_hex)"
vault_gitea_webhook_secret: "$(rand_hex)"
EOF_VAULT

chmod 600 "$VAULT_FILE"

echo "[vault] Created $VAULT_FILE with random webhook secrets."

if command -v ansible-vault >/dev/null 2>&1; then
  echo "[vault] Encrypt it now with:"
  echo "        ansible-vault encrypt ansible/inventories/dev/group_vars/vault.yml"
  echo "[vault] Then run playbooks with:"
  echo "        ANSIBLE_PLAYBOOK_ARGS=\"--ask-vault-pass\" scripts/rebuild-lab.sh"
else
  echo "[vault] ansible-vault was not found. Install Ansible, then encrypt this file."
fi
