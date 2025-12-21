#!/bin/bash

apt update
apt install -y chrony

cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak

cat > /etc/chrony/chrony.conf <<EOF
pool pool.ntp.org iburst

allow 192.168.101.0/24

local stratum 10

driftfile /var/lib/chrony/chrony.drift
EOF

systemctl restart chrony
systemctl enable chrony

#chronyc tracking — показывает состояние синхронизации времени на сервере
#chronyc sources — показывает источники времени, используемые сервером
#chronyc clients — показывает клиентов, подключавшихся к серверу времени
#ss -lun | grep 123 — проверяет, что chrony слушает порт UDP 123
