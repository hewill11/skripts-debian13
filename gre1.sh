#!/bin/bash

# Очистка старого туннеля (если уже есть)
ip tunnel del gre1 2>/dev/null

# Создание GRE-туннеля
ip tunnel add gre1 mode gre \
local 192.168.102.10 remote 192.168.101.10 ttl 255

# Назначение IP на GRE-интерфейс
ip addr add 10.10.10.1/30 dev gre1

# Поднятие интерфейса
ip link set gre1 up

# Маршрут к сети cl2 через GRE
ip route add 192.168.101.0/24 dev gre1

echo "GRE tunnel on cl1 configured successfully"
