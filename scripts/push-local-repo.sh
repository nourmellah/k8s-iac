#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GITEA_USER="${GITEA_USER:-giteaadmin}"
if [ -z "${GITEA_PASSWORD:-}" ]; then
  read -rsp "Gitea password for ${GITEA_USER}: " GITEA_PASSWORD
  echo
fi

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

GITEA_PASSWORD_ENC="$(urlencode "$GITEA_PASSWORD")"

if [ ! -d .git ]; then
  git init -b main
  git config user.name "Local Student"
  git config user.email "student@example.local"
fi

git add frontend backend kubernetes ci ci-agent ansible README.md REDESIGN_NOTES.md Vagrantfile scripts jenkins-controller .gitignore
if ! git diff --cached --quiet; then
  git commit -m "Update software factory application"
fi

if git remote | grep -qx lab; then
  git remote remove lab
fi

git remote add lab "http://${GITEA_USER}:${GITEA_PASSWORD_ENC}@192.168.56.13:30082/giteaadmin/software-factory-app.git"
git push -u -f lab main

echo "Pushed to lab Gitea repository. Authenticated Gitea webhook should trigger Jenkins automatically."
