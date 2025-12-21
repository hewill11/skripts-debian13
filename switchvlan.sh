#!/usr/bin/env bash
set -euo pipefail

UPLINK_IF="ens3"   # к router (e0)
SERVER_IF="ens4"   # к server (e1)
CLIENT_IF="ens5"   # к client (e2)

TMP_MGMT_IP="192.168.10.2/24"
TMP_GW="192.168.10.1"

MGMT_VLAN_IF="vlan999"
MGMT_IP="192.168.99.2/24"
MGMT_GW="192.168.99.1"

OVS_BR="br-ovs"

export DEBIAN_FRONTEND=noninteractive

apt update -y
apt install -y bridge-utils

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${UPLINK_IF}
iface ${UPLINK_IF} inet manual

auto ${SERVER_IF}
iface ${SERVER_IF} inet manual

auto ${CLIENT_IF}
iface ${CLIENT_IF} inet manual

auto br0
iface br0 inet static
  address ${TMP_MGMT_IP}
  gateway ${TMP_GW}
  bridge_ports ${UPLINK_IF} ${SERVER_IF} ${CLIENT_IF}
  bridge_stp off
  bridge_fd 0
EOF

systemctl restart networking

apt update -y
apt install -y openvswitch-switch

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
EOF

systemctl restart networking

ovs-vsctl --if-exists del-br ${OVS_BR}
ovs-vsctl add-br ${OVS_BR}

ovs-vsctl --may-exist add-port ${OVS_BR} ${UPLINK_IF}
ovs-vsctl --may-exist add-port ${OVS_BR} ${SERVER_IF} tag=100
ovs-vsctl --may-exist add-port ${OVS_BR} ${CLIENT_IF} tag=200

ovs-vsctl --may-exist add-port ${OVS_BR} ${MGMT_VLAN_IF} tag=999 -- set interface ${MGMT_VLAN_IF} type=internal

cat >> /etc/network/interfaces <<EOF

auto ${MGMT_VLAN_IF}
iface ${MGMT_VLAN_IF} inet static
  address ${MGMT_IP}
  gateway ${MGMT_GW}
  dns-nameservers 8.8.8.8 1.1.1.1
EOF

systemctl restart networking

#Ниже — все проверки, разнесённые по устройствам. Формат: команда — объяснение.
## ROUTER (маршрутизатор)

#ip -br a` — быстро показывает IP/состояние интерфейсов, должно быть `ens3` (DHCP) и `ens4.100/ens4.200/ens4.999` с нужными адресами.
#ip r` — таблица маршрутов, проверка что есть default через `ens3` и сети VLAN напрямую подключены.
#lsmod | grep 8021q` — проверка, что модуль VLAN (802.1Q) загружен.
#ping -c 2 192.168.99.2` — проверка связи с подсетью управления (IP свитча в VLAN 999).
#ping -c 2 192.168.100.10` — проверка доступности сервера (VLAN 100) с роутера.
#ping -c 2 192.168.200.10` — проверка доступности клиента (VLAN 200) с роутера.
#iptables-save | head` — быстрая проверка, что правила вообще сохраняются/есть.

## SWITCH (виртуальный коммутатор на Debian + OVS)
#ovs-vsctl show` — проверка конфигурации OVS: bridge, порты `ens3/ens4/ens5`, tags 100/200, internal `vlan999` tag 999.
#ovs-vsctl list-ports br-ovs` — список портов внутри OVS-моста.
#ovs-vsctl list port ens4` — проверка, что порт к серверу имеет `tag=100` (access VLAN 100).
#ovs-vsctl list port ens5` — проверка, что порт к клиенту имеет `tag=200` (access VLAN 200).
#ping -c 2 192.168.99.1` — проверка связи управления: свитч ↔ роутер по VLAN 999.

## SERVER (VLAN 100)

#ping -c 2 192.168.100.1` — проверка связи с шлюзом (роутер VLAN 100).
#ping -c 2 192.168.200.10` — проверка межVLAN-связи: сервер → клиент (маршрутизация через роутер).
#ping -c 2 192.168.99.2` — проверка доступа к управлению свитчом из VLAN 100 (если по заданию допускается).

## CLIENT (VLAN 200)

#ping -c 2 192.168.200.1` — проверка связи с шлюзом (роутер VLAN 200).
#ping -c 2 192.168.100.10` — проверка межVLAN-связи: клиент → сервер.
#ping -c 2 192.168.99.2` — проверка доступа к управлению свитчом из VLAN 200 (если по заданию допускается).


