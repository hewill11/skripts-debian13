#!/usr/bin/env bash
set -euo pipefail

# ========== НАСТРОЙКИ ДЛЯ CLIENT1 (HQ-RTR) ==========
UNDERLAY_LOCAL_IP="192.168.102.10"     # IP client1 на ens3
UNDERLAY_REMOTE_IP="192.168.101.10"    # IP client2 на ens3

GRE_IF="gre1"
GRE_LOCAL_TUN_IP="10.0.0.1/30"
GRE_REMOTE_TUN_IP="10.0.0.2"

DUMMY_IF="dummy0"
DUMMY_NET_IP="192.168.200.1/24"        # "локальная сеть HQ"

OSPF_ROUTER_ID="1.1.1.1"
OSPF_AREA="0"
OSPF_KEY_ID="1"
OSPF_MD5_PASS="password123"

echo "[1/7] Установка пакетов..."
apt update
apt install -y iproute2 frr frr-pythontools

echo "[2/7] Подготовка GRE (удаление старого, если есть)..."
# если интерфейс существует — удалим, чтобы скрипт был повторяемым
if ip link show "${GRE_IF}" &>/dev/null; then
  ip link set "${GRE_IF}" down || true
  ip tunnel del "${GRE_IF}" || true
fi

echo "[3/7] Создание GRE-туннеля ${GRE_IF}..."
ip tunnel add "${GRE_IF}" mode gre local "${UNDERLAY_LOCAL_IP}" remote "${UNDERLAY_REMOTE_IP}" ttl 64
ip addr add "${GRE_LOCAL_TUN_IP}" dev "${GRE_IF}"
ip link set "${GRE_IF}" up

echo "[4/7] Создание dummy-интерфейса ${DUMMY_IF}..."
modprobe dummy
if ip link show "${DUMMY_IF}" &>/dev/null; then
  ip addr flush dev "${DUMMY_IF}" || true
else
  ip link add "${DUMMY_IF}" type dummy
fi
ip addr add "${DUMMY_NET_IP}" dev "${DUMMY_IF}"
ip link set "${DUMMY_IF}" up

echo "[5/7] Включение ospfd в FRR (/etc/frr/daemons)..."
# В Debian в daemons обычно есть строка ospfd=no — заменим на yes.
sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons

echo "[6/7] Перезапуск FRR..."
systemctl enable frr
systemctl restart frr

echo "[7/7] Настройка OSPF через vtysh (только GRE + MD5)..."
# Настраиваем OSPF:
# - passive-interface default (везде пассивно)
# - на GRE снимаем passive НОВОЙ командой (nuance FRR): "no ip ospf passive"
# - включаем message-digest (MD5)
vtysh -c "conf t" \
      -c "router ospf" \
      -c "ospf router-id ${OSPF_ROUTER_ID}" \
      -c "passive-interface default" \
      -c "network 10.0.0.0/30 area ${OSPF_AREA}" \
      -c "network 192.168.200.0/24 area ${OSPF_AREA}" \
      -c "area ${OSPF_AREA} authentication message-digest" \
      -c "exit" \
      -c "interface ${GRE_IF}" \
      -c "no ip ospf passive" \
      -c "ip ospf authentication message-digest" \
      -c "ip ospf message-digest-key ${OSPF_KEY_ID} md5 ${OSPF_MD5_PASS}" \
      -c "exit" \
      -c "do write"

echo
echo "===== ГОТОВО: client1 настроен ====="
echo "Проверки (client1):"
echo "  ip addr show ${GRE_IF}"
echo "  ping -c 3 ${GRE_REMOTE_TUN_IP}"
echo "  vtysh -c \"show ip ospf neighbor\""
echo "  vtysh -c \"show ip route ospf\""
echo "  ping -c 3 192.168.201.1   # после настройки client2"

#Вписать на роутере перед скриптами
#iptables -A FORWARD -s 192.168.102.0/24 -d 192.168.101.0/24 -j ACCEPT
#iptables -A FORWARD -s 192.168.101.0/24 -d 192.168.102.0/24 -j ACCEPT
