#!/bin/bash

apt update
apt install -y chrony

cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak

cat > /etc/chrony/chrony.conf <<EOF
server 192.168.102.10 iburst

driftfile /var/lib/chrony/chrony.drift
EOF

systemctl restart chrony
systemctl enable chrony
