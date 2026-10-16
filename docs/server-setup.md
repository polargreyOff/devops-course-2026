## 8. Веб-сервер

- Пакет: nginx
- Конфигурация ресурса: /etc/nginx/sites-available/devops-site
- Активная ссылка: /etc/nginx/sites-enabled/devops-site
- Каталог ресурса: /var/www/devops-site
- Владелец каталога: devops:devops
- Права каталогов: 755
- Права файлов: 644
- Сертификат: /etc/ssl/certs/devops.crt
- Права сертификата: 644
- Закрытый ключ: /etc/ssl/private/devops.key
- Владелец ключа: root:root
- Права ключа: 600
- Срок действия сертификата: 365 дней
- Команда создания сертификата:

```bash 
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"