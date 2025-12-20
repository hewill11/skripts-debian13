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
