#!/bin/bash

set -e

DOMAIN=$1

# Check whether the domain has been transferred
if [ -z "$1" ]; then
    echo "Использование: $0 <домен>"
    exit 1
fi

# Function for generating random passwords
generate_password() {
    openssl rand -base64 16
}

# Function for generating random ports
generate_random_port() {
    echo $((RANDOM % 65535 + 1))
}

# Function for generating random nicknames
generate_random_nickname() {
    echo "user$(openssl rand -hex 4)"
}

# Generate random passwords
hysteria_password=$(generate_password)

vless_username=$(generate_random_nickname)
vless_password=$(generate_password)

naive_username=$(generate_random_nickname)
naive_password=$(generate_password)

# Generate random ports | or specify your desired ports
hysteria_port=$(generate_random_port)
vless_port=$(generate_random_port)
naive_port=$(generate_random_port)

# Generate ID and UUID for VLESS
vless_reality_uuid=$(sing-box generate uuid)
vless_reality_shortID=$(sing-box generate rand 8 --hex)
# Generay keypair for VLESS
vless_keypair=$(sing-box generate reality-keypair | tee /dev/tty )
vless_private_key=$(printf "%s\n" "$vless_keypair" | awk 'NR==1 {print $2}')
vless_public_key=$(printf "%s\n" "$vless_keypair" | awk 'NR==2 {print $2}')

cat <<EOL > ./new_conf.json
{
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
        "type": "vless",
        "listen": "::",
        "listen_port": $vless_port,
        "users": [
            {
                "name": "$vless_username",
                "uuid": "$vless_reality_uuid",
                "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "api.oneme.ru",
            "reality": {
                "enabled": true,
                "handshake": {
                    "server": "api.oneme.ru",
                    "server_port": $vless_port
                },
                "private_key": "$vless_private_key",
                "short_id": [
                    "$vless_reality_shortID"
                ]
            }
        },
        "multiplex": {
            "enabled": true,
            "padding": true,
            "brutal": {
                "enabled": false,
                "up_mbps": 1000,
                "down_mbps": 1000
            }
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
            "key_path": "/etc/sing-box/key.pem",
            "alpn": ["h2"]
        }
    }
]
}
EOL


echo -e "\nДанные для аутентификации:"
echo -e "Пароли
hysteria: $hysteria_password
vless: $vless_username; $vless_password
naive: $naive_username; $naive_password

\nПорты:
hysteria: $hysteria_port
vless: $vless_port
naive: $naive_port

\nVless Public Key: $vless_public_key"
