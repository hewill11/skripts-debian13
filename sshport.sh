#!/bin/bash

apt update -y
apt install -y openssh-server

id student &>/dev/null || useradd -m student
echo "student:1" | chpasswd

cat > /etc/ssh/sshd_config.d/99-lab.conf <<EOF
Port 2222
PermitRootLogin no
PasswordAuthentication yes
EOF

sshd -t || exit 1

systemctl enable ssh
systemctl restart ssh