#!/bin/bash
set -e

if [ $# -ne 1 ]; then
        echo "Usage: $0 domain_name" >&2
        exit 1
fi

do_name=$1

apt-get update && apt-get -y upgrade
apt-get -y install nginx socat
hostnamectl set-hostname $do_name
bash <(curl -L -s https://install.direct/go.sh)
curl https://get.acme.sh | sh
systemctl stop nginx
~/.acme.sh/acme.sh --issue -d $do_name --standalone -k ec-256 --log
~/.acme.sh/acme.sh --installcert -d $do_name --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
cat <<EOF >>/etc/nginx/sites-available/ssl
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    ssl on;
    ssl_certificate       /etc/v2ray/v2ray.crt;
    ssl_certificate_key   /etc/v2ray/v2ray.key;
    ssl_protocols         TLSv1.3;
    ssl_ciphers           HIGH:!aNULL:!MD5;
    server_name           $do_name;

    location /ws/ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
ln -s /etc/nginx/sites-available/ssl /etc/nginx/sites-enabled/
rm -f /etc/v2ray/config.json
cat <<EOF >>/etc/v2ray/config.json
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10000,
      "listen":"127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "a10a835a-d561-42c1-a80e-4903c31c07b3",
            "alterId": 64,
            "security": "auto",
            "level": 0
          },
	 {
            "id": "d51565ad-34bc-41e7-9700-c69498e04f86",
            "alterId": 64,
            "security": "auto",
            "level": 0
          },
	 {
            "id": "a5be326e-2d27-42e3-b726-0e429138d7a2",
            "alterId": 64,
            "security": "auto",
            "level": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

systemctl restart nginx
systemctl enable nginx
systemctl restart v2ray
systemctl enable v2ray

netstat -lntp
echo "done, enjoy!"
