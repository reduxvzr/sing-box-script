#!/bin/bash

set -e

# Проверка, был ли передан домен
if [ -z "$1" ]; then
    echo "Использование: $0 <домен>"
    exit 1
fi

DOMAIN=$1

read -p "Введите вашу почту для сертификата ACME: " user_$user_email 

# Установка sing-box на apt-based дистрибутивы
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt-get update
sudo apt-get install sing-box 

# Функция для генерации случайного пароля
generate_password() {
    openssl rand -base64 16
}

# Функция для генерации случайного порта
generate_random_port() {
    echo $((RANDOM % 65535 + 1))
}

# Функция для генерации случайного никнейма
generate_random_nickname() {
    echo "user$(openssl rand -hex 4)"
}

# Генерация случайных паролей
hysteria_password=$(generate_password)
naive_username=$(generate_random_nickname)
naive_password=$(generate_password)

# Генерация случайных портов
hysteria_port=$(generate_random_port)
naive_port=$(generate_random_port)

# Генерация ключей и сертификатов
sing-box generate tls-keypair "$DOMAIN" > output.txt

# Извлечение приватного ключа
awk '/-----BEGIN PRIVATE KEY-----/{flag=1} flag; /-----END PRIVATE KEY-----/{flag=0}' output.txt > /etc/sing-box/key.pem

# Извлечение сертификата
awk '/-----BEGIN CERTIFICATE-----/{flag=1} flag; /-----END CERTIFICATE-----/{flag=0}' output.txt > /etc/sing-box/cert.pem

# Удаление временного файла
rm output.txt

# Создание нового файла конфигурации
cat <<EOL > /tmp/new_conf.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "/var/lib/box.log",
        "timestamp": true
    },

    "dns": {
        "servers": [
            {
                "tag": "local",
                "type": "local"
            }
        ]
    },

    "route": {
        "rules": [
            {
                "ip_is_private": true,
                "outbound": "direct"
            },
            {
                "rule_set": "geoip-ru",
                "outbound": "direct"
            }
        ],
        "rule_set": [
            {
                "tag": "geoip-ru",
                "type": "remote",
                "format": "binary",
                "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs"
            }
        ]
    },

    "inbounds": [
        {
            "type": "hysteria2",
            "listen": "::",
            "listen_port": $hysteria_port,
            "up_mbps": 300,
            "down_mbps": 300,
            "obfs": {
                "type": "salamander",
                "password": "$hysteria_password"
            },
            "users": [
                {
                    "password": "$hysteria_password"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$DOMAIN",
                "certificate_path": "/etc/sing-box/cert.pem",
                "key_path": "/etc/sing-box/key.pem"
            }
        },
        {
            "type": "naive",
            "listen": "::",
            "listen_port": $naive_port,
            "users": [
                {
                    "username": "$naive_username",
                    "password": "$naive_password"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$DOMAIN",
                "certificate_path": "/etc/sing-box/cert.pem",
                "key_path": "/etc/sing-box/key.pem"
                "alpn": ["h2"]
            }
        }
    ],

    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOL

# Копирование нового файла конфигурации
cp /tmp/new_conf.json /etc/sing-box/server.json

# Удаление временного файла
rm /tmp/new_conf.json

# Создание файла логов
touch /var/lib/box.json
chmod sing-box: /var/lib/box.log

echo "Ключи и сертификат успешно сохранены."
echo "Конфигурация обновлена."
echo -e "Проверка конфигурации.\n"
sing-box check -c /etc/sing-box/server.json

echo -e "\nДанные для аутентификации:"
echo -e "Пароли
hysteria: $hysteria_password
naive: $naive_username; $naive_password

\nПорты:
hysteria: $hysteria_port
naive: $naive_port
"

echo -e "\n\nЗапуск и проверка работоспособности демона Sing-Box.\n"

/usr/bin/sing-box check --config /etc/sing-box/server.json && /usr/bin/sing-box format --config /etc/sing-box/server.json -w

systemctl start sing-box@server.service

echo -e '\n\n'

systemctl status sing-box@server.service
