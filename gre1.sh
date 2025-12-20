#!/bin/bash
set -e

# cl1: local 192.168.102.10 -> remote 192.168.101.10
ip tunnel del gre1 2>/dev/null || true

ip tunnel add gre1 mode gre local 192.168.102.10 remote 192.168.101.10 ttl 255
ip addr add 10.10.10.1/30 dev gre1
ip link set gre1 up

echo "cl1: GRE gre1 поднят (10.10.10.1/30)"
