#!/usr/bin/env bash
set -euo pipefail

# ===== НАСТРОЙКИ =====
IFACE="ens3"
IP_ADDR="192.168.20.2/24"
GW="192.168.20.1"
DNS="192.168.20.1"

echo "[DNS-CLIENT] 1) Установка пакетов (только утилиты проверки)..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y dnsutils iputils-ping

echo "[DNS-CLIENT] 2) Настройка сети (/etc/network/interfaces)..."
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${IFACE}
iface ${IFACE} inet static
  address ${IP_ADDR}
  gateway ${GW}
  dns-nameservers ${DNS}
EOF

systemctl restart networking

echo "[DNS-CLIENT] 3) Быстрая проверка интернета (ping 8.8.8.8)..."
ping -c 2 8.8.8.8 || true

echo "[DNS-CLIENT] 4) Проверка DNS через роутер (dig)..."
dig @${DNS} client.local.lab || true

echo "[DNS-CLIENT] ГОТОВО."
