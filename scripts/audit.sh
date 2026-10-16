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

[[ $FAIL -eq 0 ]] && exit 0 || exit 1   