#!/usr/bin/env bash
set -euo pipefail

# IFACES (как на скрине)
WAN_IF="ens3"     # в сторону магистрального провайдера (DHCP)
HQ_IF="ens4"      # в сторону HQ-RTR (172.16.1.0/28)
BR_IF="ens5"      # в сторону BR-RTR (172.16.2.0/28)

echo "[1/5] Backup configs..."
cp -a /etc/network/interfaces /etc/network/interfaces.bak.$(date +%F_%T) 2>/dev/null || true
cp -a /etc/nftables.conf /etc/nftables.conf.bak.$(date +%F_%T) 2>/dev/null || true

echo "[2/5] Write /etc/network/interfaces..."
cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ${WAN_IF}
iface ${WAN_IF} inet dhcp

auto ${HQ_IF}
iface ${HQ_IF} inet static
  address 172.16.1.1/28

auto ${BR_IF}
iface ${BR_IF} inet static
  address 172.16.2.1/28

post-up nft -f /etc/nftables.conf
EOF

echo "[3/5] Enable IPv4 forwarding..."
cat > /etc/sysctl.d/99-pnet-forward.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

echo "[4/5] Configure nftables NAT (маскарадинг в Интернет)..."
cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100; policy accept;

    # НЕ трогаем некоторые протоколы туннелей/маршрутизации (как в методичке)
    meta l4proto { gre, ipip, ospf } counter return

    # NAT наружу (поменяй oifname если WAN другой)
    oifname "ens3" masquerade
  }
}

table inet filter {
  chain input  { type filter hook input priority 0; policy accept; }
  chain forward{ type filter hook forward priority 0; policy accept; }
  chain output { type filter hook output priority 0; policy accept; }
}
EOF

echo "[5/5] Enable & restart services..."
systemctl enable --now nftables >/dev/null || true
systemctl restart networking

echo "DONE: ISP configured."
ip -br a