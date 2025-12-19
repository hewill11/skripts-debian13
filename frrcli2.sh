#!/usr/bin/env bash
set -euo pipefail

# ========== НАСТРОЙКИ ДЛЯ CLIENT2 (BR-RTR) ==========
UNDERLAY_LOCAL_IP="192.168.101.10"     # IP client2 на ens3
UNDERLAY_REMOTE_IP="192.168.102.10"    # IP client1 на ens3

GRE_IF="gre1"
GRE_LOCAL_TUN_IP="10.0.0.2/30"
GRE_REMOTE_TUN_IP="10.0.0.1"

DUMMY_IF="dummy0"
DUMMY_NET_IP="192.168.201.1/24"        # "локальная сеть BR"

OSPF_ROUTER_ID="2.2.2.2"
OSPF_AREA="0"
OSPF_KEY_ID="1"
OSPF_MD5_PASS="password123"            # ДОЛЖЕН совпадать с client1

echo "[1/7] Установка пакетов..."
apt update
apt install -y iproute2 frr frr-pythontools

echo "[2/7] Подготовка GRE (удаление старого, если есть)..."
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
sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons

echo "[6/7] Перезапуск FRR..."
systemctl enable frr
systemctl restart frr

echo "[7/7] Настройка OSPF через vtysh (только GRE + MD5)..."
vtysh -c "conf t" \
      -c "router ospf" \
      -c "ospf router-id ${OSPF_ROUTER_ID}" \
      -c "passive-interface default" \
      -c "network 10.0.0.0/30 area ${OSPF_AREA}" \
      -c "network 192.168.201.0/24 area ${OSPF_AREA}" \
      -c "area ${OSPF_AREA} authentication message-digest" \
      -c "exit" \
      -c "interface ${GRE_IF}" \
      -c "no ip ospf passive" \
      -c "ip ospf authentication message-digest" \
      -c "ip ospf message-digest-key ${OSPF_KEY_ID} md5 ${OSPF_MD5_PASS}" \
      -c "exit" \
      -c "do write"

echo
echo "===== ГОТОВО: client2 настроен ====="
echo "Проверки (client2):"
echo "  ip addr show ${GRE_IF}"
echo "  ping -c 3 ${GRE_REMOTE_TUN_IP}"
echo "  vtysh -c \"show ip ospf neighbor\""
echo "  vtysh -c \"show ip route ospf\""
echo "  ping -c 3 192.168.200.1"
