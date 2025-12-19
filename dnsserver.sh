#!/usr/bin/env bash
set -euo pipefail

# ===== НАСТРОЙКИ =====
IFACE="ens3"
IP_ADDR="192.168.10.2/24"
GW="192.168.10.1"
UPSTREAM_DNS="8.8.8.8"

ZONE_NAME="local.lab"
ZONE_FILE="/etc/bind/db.local.lab"
NS_NAME="ns.local.lab."
ADMIN_NAME="admin.local.lab."
NS_A="192.168.10.2"
CLIENT_A="192.168.20.2"

SERIAL="$(date +%Y%m%d)01"

echo "[DNS-SERVER] 1) Установка пакетов..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y bind9 dnsutils

echo "[DNS-SERVER] 2) Настройка сети (/etc/network/interfaces)..."
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${IFACE}
iface ${IFACE} inet static
  address ${IP_ADDR}
  gateway ${GW}
  dns-nameservers ${UPSTREAM_DNS}
EOF

systemctl restart networking

echo "[DNS-SERVER] 3) BIND9: named.conf.options (разрешаем запросы/рекурсию)..."
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    listen-on { any; };
    listen-on-v6 { any; };

    allow-query { any; };
    allow-recursion { any; };
    recursion yes;

    dnssec-validation auto;
};
EOF

echo "[DNS-SERVER] 4) Подключение зоны ${ZONE_NAME}..."
cat > /etc/bind/named.conf.local <<EOF
// Local zones
zone "${ZONE_NAME}" {
    type master;
    file "${ZONE_FILE}";
};
EOF

echo "[DNS-SERVER] 5) Создание файла зоны ${ZONE_FILE}..."
cat > "${ZONE_FILE}" <<EOF
\$TTL 604800
@ IN SOA ${NS_NAME} ${ADMIN_NAME} (
  ${SERIAL}
  604800
  86400
  2419200
  604800 )

@      IN NS ${NS_NAME}
ns     IN A  ${NS_A}
client IN A  ${CLIENT_A}
EOF

echo "[DNS-SERVER] 6) Проверки BIND: named-checkconf / named-checkzone..."
named-checkconf
named-checkzone "${ZONE_NAME}" "${ZONE_FILE}"

echo "[DNS-SERVER] 7) Перезапуск bind9..."
systemctl enable --now bind9
systemctl restart bind9

echo "[DNS-SERVER] ГОТОВО."
echo "Проверка (на DNS-server): dig @127.0.0.1 client.${ZONE_NAME}"
