# Конфигурация виртуальной машины devops-vm

## 1. Параметры виртуальной машины

- Гипервизор: Oracle VirtualBox 7.x
- Операционная система: Ubuntu Server 26.04.1 LTS
- Оперативная память: 2048 МБ
- Количество процессоров: 2
- Виртуальный диск: 25 ГБ, динамически расширяемый
- Имя виртуальной машины: devops-vm

## 2. Сетевые интерфейсы

**Адаптер 1 — NAT**

- Интерфейс Ubuntu: `enp0s3`
- IP-адрес: `10.0.2.15/24`
- Назначение: доступ виртуальной машины к интернету.

**Адаптер 2 — Host-only**

- Интерфейс Ubuntu: `enp0s8`
- IP-адрес Ubuntu: `192.168.56.101/24`
- IP-адрес Windows: `192.168.56.1`
- Назначение: прямое взаимодействие Windows и виртуальной машины.

## 3. Проброс портов

Адаптер NAT:

| Параметр | Значение |
|---|---|
| Название | ssh |
| Протокол | TCP |
| IP хоста | 127.0.0.1 |
| Порт хоста | 2222 |
| IP гостя | Не задан |
| Порт гостя | 2222 |

Подключение с Windows:

`ssh devops`

## 4. Учётные записи

**student**

Первоначальная учётная запись Ubuntu.

**devops**

Учётная запись для администрирования и доставки веб-ресурса.

- Группы: `devops`, `sudo`
- SSH-аутентификация: по ключу ED25519
- Парольная SSH-аутентификация отключена.

Публичный ключ клиента хранится на сервере:

`/home/devops/.ssh/authorized_keys`

Права:

- `~/.ssh` — 700
- `authorized_keys` — 600

## 5. Конфигурация SSH

Основной файл:

`/etc/ssh/sshd_config`

Дополнительная конфигурация:

`/etc/ssh/sshd_config.d/99-hardening.conf`

Параметры:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Применение и проверка:

```bash
sudo sshd -t
sudo systemctl restart ssh
sudo sshd -T
sudo ss -tlnp | grep sshd
```

При изменениях SSH необходимо сохранять действующую сессию и проверять новое подключение отдельно.

## 6. Межсетевой экран UFW

Политики по умолчанию:

- Входящий трафик: deny
- Исходящий трафик: allow

Разрешённые порты:

| Порт | Назначение | Правило |
|---|---|---|
| 2222/TCP | SSH | LIMIT |
| 80/TCP | HTTP | ALLOW |
| 443/TCP | HTTPS | ALLOW |

Команды настройки:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw enable
```

Проверка:

```bash
sudo ufw status verbose
```

Логирование:

```bash
sudo ufw logging medium
```

Журнал блокировок:

`/var/log/ufw.log`

## 7. Снимки состояния

- `01-clean-install` — установка Ubuntu, настройка сети и SSH.
- `02-keys-configured` — настройка пользователя devops и ключевой аутентификации.
- `03-ssh-hardened` — усиление защиты SSH.
- `04-nginx-https` — настройка веб-сервера и HTTPS.

Снимки позволяют восстанавливать рабочее состояние виртуальной машины после ошибок конфигурации.

## 8. Веб-сервер

**Установленный пакет:** nginx

Основная конфигурация:

`/etc/nginx/nginx.conf`

Конфигурация ресурса:

`/etc/nginx/sites-available/devops-site`

Активная символическая ссылка:

`/etc/nginx/sites-enabled/devops-site`

Стандартный ресурс Nginx отключён.

**Каталог ресурса:**

`/var/www/devops-site`

- Владелец: `devops`
- Права каталогов: 755
- Права файлов: 644
- Рабочие процессы Nginx выполняются от имени `www-data`.

### HTTPS

Сертификат:

`/etc/ssl/certs/devops.crt`

- Владелец: root
- Права: 644
- Срок действия: 365 дней
- SAN: `DNS:devops.local`

Закрытый ключ:

`/etc/ssl/private/devops.key`

- Владелец: root
- Права: 600

Команда формирования сертификата:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"
```

HTTP-запросы на порт 80 перенаправляются на HTTPS с кодом 301.

### Проверка веб-сервера

```bash
sudo nginx -t
systemctl status nginx --no-pager
sudo ss -tlnp | grep nginx
```

### Доставка содержимого

Исходные файлы сайта находятся в Git-репозитории:

`site/`

Для доставки используется:

`scripts/deploy.sh`

Скрипт выполняет синхронизацию через rsync, устанавливает права 755/644 и проверяет доступность HTTPS-ресурса.

### Аудит конфигурации

`scripts/audit.sh`

Проверяет SSH, UFW, Nginx, TLS-сертификат и права доступа. Код возврата 0 означает успешную проверку, 1 — обнаружение нарушений.