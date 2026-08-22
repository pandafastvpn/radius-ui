#!/bin/bash
# Configure FreeRADIUS SQL authorization and accounting for external NAS clients.

set -euo pipefail

RADIUS_ROOT=""
for candidate in /etc/freeradius/3.0 /etc/raddb; do
    if [ -d "$candidate" ]; then
        RADIUS_ROOT="$candidate"
        break
    fi
done

if [ -z "$RADIUS_ROOT" ]; then
    echo "[FreeRADIUS] Configuration directory not found."
    exit 1
fi

ensure_sql_in_section() {
    local file="$1"
    local section="$2"

    [ -f "$file" ] || return 0

    python3 - "$file" "$section" <<'PY'
import re
import sys

path, section = sys.argv[1:]
text = open(path, encoding="utf-8").read()
match = re.search(rf'(?m)^(\s*){re.escape(section)}\s*\{{', text)
if not match:
    raise SystemExit(0)

start = match.end()
depth = 1
pos = start
while pos < len(text) and depth:
    if text[pos] == '{':
        depth += 1
    elif text[pos] == '}':
        depth -= 1
    pos += 1

body = text[start:pos - 1]
# Normalize stock templates, which may contain `# sql`, `-sql`, or no SQL call.
body = re.sub(r'(?m)^(\s*)#\s*-?sql\s*$', r'\1sql', body)
body = re.sub(r'(?m)^(\s*)-sql\s*$', r'\1sql', body)
if not re.search(r'(?m)^\s*sql\s*$', body):
    indent = match.group(1) + '\t'
    body = body.rstrip() + '\n' + indent + 'sql\n'
text = text[:start] + body + text[pos - 1:]
open(path, 'w', encoding="utf-8").write(text)
PY
}

# The SQL module must run in both sites.  In particular, the accounting section
# writes Start, Interim-Update and Stop packets into radacct.
for site in "$RADIUS_ROOT/sites-available/default" "$RADIUS_ROOT/sites-available/inner-tunnel"; do
    ensure_sql_in_section "$site" authorize
    ensure_sql_in_section "$site" accounting
done

# Fail fast if the active site still has no SQL accounting handler.
for site in "$RADIUS_ROOT/sites-enabled/default" "$RADIUS_ROOT/sites-enabled/inner-tunnel"; do
    [ -f "$site" ] || continue
    grep -qE '^[[:space:]]*sql[[:space:]]*$' "$site" || {
        echo "[FreeRADIUS] SQL module is missing in $site"
        exit 1
    }
done

# Keep installed site symlinks intact; restart validates the effective config.
if systemctl cat freeradius.service >/dev/null 2>&1; then
    systemctl restart freeradius
elif systemctl cat radiusd.service >/dev/null 2>&1; then
    systemctl restart radiusd
else
    echo "[FreeRADIUS] Neither freeradius.service nor radiusd.service exists."
    exit 1
fi

echo "[FreeRADIUS] SQL authorization and accounting are enabled."
