#!/bin/bash

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
shadowsocks_password=$(generate_password)
hysteria_password=$(generate_password)
naive_username=$(generate_random_nickname)
naive_password=$(generate_password)
vless_uuid=$(uuidgen)

# Генерация случайных портов
shadowsocks_port=$(generate_random_port)
hysteria_port=$(generate_random_port)
naive_port=$(generate_random_port)
vless_port=$(generate_random_port)

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
        "output": "/root/box.log",
        "timestamp": true
    },
    "dns": {
        "servers": [
            {
                "tag": "cloudflare",
                "address": "tls://1.1.1.1"
            },
            {
                "tag": "block",
                "address": "rcode://success"
            }
        ],
        "final": "cloudflare",
        "strategy": "prefer_ipv4",
        "disable_cache": false,
        "disable_expire": false
    },
    "inbounds": [
        {
            "type": "shadowsocks",
            "listen": "::",
            "listen_port": $shadowsocks_port,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$shadowsocks_password",
            "multiplex": {
                "enabled": true
            }
        },
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
                "acme" : {
                    "domain": "$DOMAIN",
                    "email": "$user_email"
                },
                "alpn": [
                    "h3"
                ]
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
                "acme": {
                   "domain": "$DOMAIN",
                   "email": "$user_email"
                }
            }
        },
        {
            "type": "vless",
            "listen": "::",
            "listen_port": $vless_port,
            "users" : [
                {
                    "uuid": "$vless_uuid",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$DOMAIN",
                "certificate_path": "/etc/sing-box/cert.pem",
                "key_path": "/etc/sing-box/key.pem"
                },
            "multiplex": {
                "enabled": true
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
EOL

# Копирование нового файла конфигурации
cp /tmp/new_conf.json /etc/sing-box/config.json

# Удаление временного файла
rm /tmp/new_conf.json

echo "Ключи и сертификат успешно сохранены."
echo "Конфигурация обновлена."
echo -e "Проверка конфигурации.\n"
sing-box check -c /etc/sing-box/config.json

echo -e "\nДанные для аутентификации:"
echo -e "Пароли
shadowsocks: $shadowsocks_password 
hysteria: $hysteria_password
naive: $naive_username; $naive_password
vless_uuid: $vless_uuid

\nПорты:
shadowsocks: $shadowsocks_port
hysteria: $hysteria_port
naive: $naive_port
vless: $vless_port
"

# Создание демона systemd для sing-box
touch /etc/systemd/system/sing-box.service

echo "
[Unit]
Description=Sing-Box service
After=network.target

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sing-box.service
systemctl daemon-reload

echo -e "\n\nЗапуск и проверка работоспособности демона Sing-Box.\n"

systemctl start sing-box.service 

echo -e '\n\n'

systemctl status sing-box.service
