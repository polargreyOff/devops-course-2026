#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        ((PASS+=1))
    else
        echo "[FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL+=1))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход root запрещён" "no" \
    "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" "no" \
    "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

SSH_PORT="$(sudo sshd -T | awk '/^port/{print $2}')"

if [[ "$SSH_PORT" != "22" && -n "$SSH_PORT" ]]; then
    check "Порт SSH нестандартный" "yes" "yes"
else
    check "Порт SSH нестандартный" "yes" "no"
fi

check "Максимум попыток SSH" "3" \
    "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "UFW активен" "active" \
    "$(sudo ufw status | awk '/^Status:/{print $2}')"

UFW_DEFAULT="$(sudo ufw status verbose | grep 'Default:')"

if [[ "$UFW_DEFAULT" == *"deny (incoming)"* ]]; then
    check "Входящий трафик запрещён по умолчанию" "deny" "deny"
else
    check "Входящий трафик запрещён по умолчанию" "deny" "other"
fi

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {
    printf "%s (uid=%s)\n", $1, $3
}' /etc/passwd

echo "[4] Веб-сервер"

check "Nginx активен" "active" \
    "$(systemctl is-active nginx)"

if sudo nginx -t >/dev/null 2>&1; then
    check "Конфигурация Nginx" "ok" "ok"
else
    check "Конфигурация Nginx" "ok" "fail"
fi

if openssl x509 -checkend 2592000 \
    -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then
    check "Сертификат действителен ещё 30 дней" "ok" "ok"
else
    check "Сертификат действителен ещё 30 дней" "ok" "fail"
fi

WORLD_WRITABLE="$(find /var/www/devops-site -perm -o+w -print -quit)"

check "Нет файлов с правом записи для всех" "" "$WORLD_WRITABLE"

check "Права приватного ключа TLS" "600" \
    "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "Пройдено: $PASS, не пройдено: $FAIL"

echo "[5] Контейнеризация"

check "Docker активен" "active" \
    "$(systemctl is-active docker)"

DB_STATUS="$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)"

check "PostgreSQL healthy" "healthy" "$DB_STATUS"

UNSAFE_PORTS="$(sudo ss -H -tln | awk '
    $4 ~ /:(5000|5432)$/ &&
    $4 !~ /^127\.0\.0\.1:/ {
        print $4
    }
')"

check "Порты 5000 и 5432 не открыты наружу" "" "$UNSAFE_PORTS"

check "Права файла .env" "600" \
    "$(stat -c '%a' /home/devops/app/.env 2>/dev/null)"

echo "[6] Контрольная работа № 2"

# 1. Проверка Redis
REDIS_ID="$(docker compose --project-directory /home/devops/kr2 ps -q redis 2>/dev/null)"

if [[ -n "$REDIS_ID" ]]; then
    REDIS_STATUS="$(docker inspect -f '{{.State.Health.Status}}' "$REDIS_ID" 2>/dev/null)"
else
    REDIS_STATUS=""
fi

check "Redis KR2 healthy" "healthy" "$REDIS_STATUS"


# 2. Проверка публикации порта Flask
APP_PORT="$(docker compose --project-directory /home/devops/kr2 port app 8003 2>/dev/null)"

check "KR2 доступен только на localhost" "127.0.0.1:8003" "$APP_PORT"


# 3. Права файла .env
check "Права KR2 .env" "600" \
    "$(stat -c '%a' /home/devops/kr2/.env 2>/dev/null)"


# 4. Сертификат действителен минимум 30 дней
if openssl x509 -checkend 2592000 \
    -noout -in /etc/ssl/certs/kr2.crt >/dev/null 2>&1; then
    check "Сертификат KR2 действителен ещё 30 дней" "ok" "ok"
else
    check "Сертификат KR2 действителен ещё 30 дней" "ok" "fail"
fi


# 5. Сайт активирован в Nginx
if [[ -L /etc/nginx/sites-enabled/kr2 && -e /etc/nginx/sites-enabled/kr2 ]]; then
    check "Сайт KR2 активирован в Nginx" "yes" "yes"
else
    check "Сайт KR2 активирован в Nginx" "yes" "no"
fi

[[ $FAIL -eq 0 ]] && exit 0 || exit 1   