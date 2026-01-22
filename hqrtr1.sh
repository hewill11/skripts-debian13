#!/usr/bin/env bash
set -euo pipefail

# В методичке на HQ-RTR это ens3 в сторону ISP
UPLINK_IF="ens3"

# 0) Бэкапы (не мешают методичке, но спасают жизнь)
cp -a /etc/network/interfaces /etc/network/interfaces.bak.$(date +%F_%T) 2>/dev/null || true
cp -a /etc/nftables.conf /etc/nftables.conf.bak.$(date +%F_%T) 2>/dev/null || true
cp -a /etc/sysctl.d/sysctl.conf /etc/sysctl.d/sysctl.conf.bak.$(date +%F_%T) 2>/dev/null || true

echo "[1/5] /etc/network/interfaces (как в методичке)..."
cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ${UPLINK_IF}
iface ${UPLINK_IF} inet static
  address 172.16.1.2/28
  gateway 172.16.1.1

post-up nft -f /etc/nftables.conf
EOF

echo "[2/5] /etc/sysctl.d/sysctl.conf (как в методичке)..."
cat > /etc/sysctl.d/sysctl.conf <<'EOF'
net.ipv4.ip_forward=1
EOF

echo "[3/5] sysctl --system (как в методичке)..."
sysctl --system >/dev/null

echo "[4/5] /etc/nftables.conf (masquerade как в методичке)..."
cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100; policy accept
    meta l4proto { gre, ipip, ospf } counter return
    masquerade
  }
}

table inet filter {
  chain input {
    type filter hook input priority filter;
  }
  chain forward {
    type filter hook forward priority filter;
  }
  chain output {
    type filter hook output priority filter;
  }
}
EOF

echo "[5/5] Перезапуск сети (как в методичке)..."
systemctl restart networking

echo "=== CHECK ==="
ip -br a
echo "ip_forward=$(sysctl -n net.ipv4.ip_forward)"