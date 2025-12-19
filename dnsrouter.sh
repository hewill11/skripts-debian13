#!/usr/bin/env bash
set -euo pipefail

# ===== НАСТРОЙКИ (можно менять при необходимости) =====
WAN_IF="ens3"              # DHCP (Интернет)
LAN1_IF="ens4"             # к DNS-server
LAN2_IF="ens5"             # к DNS-client
LAN1_IP="192.168.10.1/24"
LAN2_IP="192.168.20.1/24"
DNS_SERVER_IP="192.168.10.2"
ZONE_NAME="local.lab"

echo "[ROUTER] 1) Установка пакетов..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y iptables bind9 dnsutils

echo "[ROUTER] 2) Настройка сети (/etc/network/interfaces)..."
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${WAN_IF}
iface ${WAN_IF} inet dhcp

auto ${LAN1_IF}
iface ${LAN1_IF} inet static
  address ${LAN1_IP}

auto ${LAN2_IF}
iface ${LAN2_IF} inet static
  address ${LAN2_IP}
EOF

systemctl restart networking

echo "[ROUTER] 3) Включение маршрутизации (net.ipv4.ip_forward=1)..."
if ! grep -q '^net\.ipv4\.ip_forward=1' /etc/sysctl.conf; then
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
sysctl -p >/dev/null

echo "[ROUTER] 4) NAT (iptables)..."
# Сбрасываем старые правила, чтобы скрипт можно было запускать повторно
iptables -F
iptables -t nat -F

iptables -t nat -A POSTROUTING -o "${WAN_IF}" -j MASQUERADE
iptables -A FORWARD -i "${LAN1_IF}" -o "${WAN_IF}" -j ACCEPT
iptables -A FORWARD -i "${LAN2_IF}" -o "${WAN_IF}" -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "[ROUTER] 5) BIND9: named.conf.options (forwarders внутри options)..."
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    listen-on { any; };
    listen-on-v6 { any; };

    allow-query { any; };
    allow-recursion { any; };
    recursion yes;

    // Чтобы не ловить SERVFAIL в учебной локальной зоне через форвардинг
    dnssec-validation no;
};
EOF

echo "[ROUTER] 6) BIND9: conditional forwarding зоны ${ZONE_NAME} на DNS-server..."
cat > /etc/bind/named.conf.local <<EOF
// Local BIND configuration

zone "${ZONE_NAME}" {
    type forward;
    forward only;
    forwarders { ${DNS_SERVER_IP}; };
};
EOF

echo "[ROUTER] 7) Проверка конфигов BIND..."
named-checkconf

echo "[ROUTER] 8) Перезапуск bind9..."
systemctl enable --now bind9
systemctl restart bind9

echo "[ROUTER] 9) Проверка, что 53/udp слушается..."
ss -lunp | grep -E ':(53)\b' || true

echo "[ROUTER] ГОТОВО."
echo "Проверка (на роутере): dig @127.0.0.1 ${ZONE_NAME} SOA"

#Настройки для устройств ens4 - server; ens5 - client
# auto ens3                     auto ens3
# iface ens3 inet static        iface ens3 inet static
# address 192.168.10.2/24       address 192.168.20.2/24
# gateway 192.168.10.1          gateway 192.168.20.1
# dns-nameservers 8.8.8.8       dns-nameservers 192.168.20.1

#Команды для проверки клиента
#ping -c 2 192.168.20.1 — проверяет, доступен ли роутер и работает ли сеть между клиентом и шлюзом.
#dig client.local.lab — проверяет, может ли клиент разрешить имя через DNS, указанный в /etc/resolv.conf.
#dig @192.168.20.1 client.local.lab — напрямую проверяет работу DNS на роутере и пересылку запроса к DNS-серверу.
#ping client.local.lab — итоговая проверка: DNS-разрешение имени и сетевую доступность узла по имени.

