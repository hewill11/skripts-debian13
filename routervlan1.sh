#!/usr/bin/env bash
set -euo pipefail

WAN_IF="ens3"
LAN_IF="ens4"
LAN_IP="192.168.10.1/24"

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${WAN_IF}
iface ${WAN_IF} inet dhcp

auto ${LAN_IF}
iface ${LAN_IF} inet static
  address ${LAN_IP}
EOF

if grep -qE '^\s*net\.ipv4\.ip_forward\s*=' /etc/sysctl.conf; then
  sed -i 's/^\s*net\.ipv4\.ip_forward\s*=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
  printf '\nnet.ipv4.ip_forward=1\n' >> /etc/sysctl.conf
fi
sysctl -p >/dev/null

systemctl restart networking

export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y iptables iptables-persistent

iptables -t nat -C POSTROUTING -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o "${WAN_IF}" -j MASQUERADE

iptables -C FORWARD -i "${LAN_IF}" -o "${WAN_IF}" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "${LAN_IF}" -o "${WAN_IF}" -j ACCEPT

iptables -C FORWARD -i "${WAN_IF}" -o "${LAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "${WAN_IF}" -o "${LAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables-save > /etc/iptables/rules.v4

#После того как применили скрипт, указываем следующие настройки интерфейсов на свитче
#auto lo
#iface lo inet loopback

#auto ens3
#iface ens3 inet static
# address 192.168.10.2/24
# gateway 192.168.10.1
