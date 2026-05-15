#!/usr/bin/env bash
set -euo pipefail

GITEA_HOST="192.168.56.13:30082"
GITEA_USER="giteaadmin"
REPO_PATH="giteaadmin/software-factory-app.git"
BRANCH="main"

read -rsp "Gitea password for ${GITEA_USER}: " GITEA_PASSWORD
echo

TMP_DIR="$(mktemp -d)"
ASKPASS_FILE="$(mktemp)"
trap 'rm -rf "$TMP_DIR" "$ASKPASS_FILE"' EXIT

cat > "$ASKPASS_FILE" <<EOF
#!/usr/bin/env bash
case "\$1" in
  *Username*) echo "${GITEA_USER}" ;;
  *Password*) echo "${GITEA_PASSWORD}" ;;
  *) echo "${GITEA_PASSWORD}" ;;
esac
EOF

chmod +x "$ASKPASS_FILE"

export GIT_ASKPASS="$ASKPASS_FILE"
export GIT_TERMINAL_PROMPT=0

REPO_URL="http://${GITEA_HOST}/${REPO_PATH}"

echo "[demo] Cloning Gitea repository..."
git clone "$REPO_URL" "$TMP_DIR/repo"

cd "$TMP_DIR/repo"

git config user.name "Demo Developer"
git config user.email "demo@example.local"

git checkout "$BRANCH"

FRONTEND_FILE="frontend/index.html"

if [ ! -f "$FRONTEND_FILE" ]; then
  echo "[ERROR] Cannot find $FRONTEND_FILE in the Gitea repository."
  exit 1
fi

RANDOM_COLOR="$(printf '#%06X' "$(( RANDOM * RANDOM % 16777215 ))")"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

echo "[demo] New random background color: $RANDOM_COLOR"

python3 - "$FRONTEND_FILE" "$RANDOM_COLOR" "$TIMESTAMP" <<'PY'
import re
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
color = sys.argv[2]
timestamp = sys.argv[3]

text = file_path.read_text()

css_block = f"""
/* DEMO_RANDOM_BG_START */
body {{
  background: {color} !important;
}}

#demo-version {{
  margin-top: 1rem;
  font-weight: 700;
  color: #ffffff;
  background: rgba(0, 0, 0, 0.35);
  padding: 0.75rem 1rem;
  border-radius: 0.75rem;
  display: inline-block;
}}
/* DEMO_RANDOM_BG_END */
"""

if "/* DEMO_RANDOM_BG_START */" in text:
    text = re.sub(
        r"/\* DEMO_RANDOM_BG_START \*/.*?/\* DEMO_RANDOM_BG_END \*/",
        css_block.strip(),
        text,
        flags=re.DOTALL,
    )
elif "</style>" in text:
    text = text.replace("</style>", css_block + "\n</style>", 1)
elif "</head>" in text:
    text = text.replace("</head>", f"<style>{css_block}</style>\n</head>", 1)
else:
    text = f"<style>{css_block}</style>\n" + text

demo_line = f'<p id="demo-version">Demo update pushed at {timestamp} — background {color}</p>'

if 'id="demo-version"' in text:
    text = re.sub(
        r'<p id="demo-version">.*?</p>',
        demo_line,
        text,
        flags=re.DOTALL,
    )
elif "</main>" in text:
    text = text.replace("</main>", f"  {demo_line}\n</main>", 1)
elif "</body>" in text:
    text = text.replace("</body>", f"{demo_line}\n</body>", 1)
else:
    text += "\n" + demo_line + "\n"

file_path.write_text(text)
PY

git add "$FRONTEND_FILE"

if git diff --cached --quiet; then
  echo "[demo] No change detected."
  exit 0
fi

git commit -m "Demo update frontend background ${RANDOM_COLOR}"

echo "[demo] Pushing change to Gitea..."
git push origin "$BRANCH"

echo
echo "[demo] Pushed frontend demo change to Gitea."
echo "[demo] Jenkins should trigger automatically through the secure webhook."
echo "[demo] Jenkins: http://192.168.56.10:30080"
echo "[demo] App:     http://192.168.56.10:30081"
