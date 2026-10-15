#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=""

# Разбор аргументов
if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN="--dry-run"
    else
        echo "Unknown argument: $1" >&2
        exit 1
    fi
fi

# Проверка index.html
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Error: site/index.html not found" >&2
    exit 1
fi

# Проверка незакоммиченных изменений
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: repository has uncommitted changes" >&2
    exit 1
fi

# Доставка
rsync -avz --delete --chmod=D755,F644 \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    ${DRY_RUN} \
    "${LOCAL_DIR}" \
    "${REMOTE}:${REMOTE_DIR}/"

# При dry-run дальше сайт не проверяем
if [[ -n "${DRY_RUN}" ]]; then
    echo "Dry-run completed"
    exit 0
fi

# Проверка сайта
curl -f --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null

# Хеш доставленного коммита
echo "Deployed commit: $(git rev-parse --short HEAD)"
