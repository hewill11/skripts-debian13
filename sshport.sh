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

#SSH — это защищённый протокол удалённого доступа, который использует шифрование, аутентификацию и проверку подлинности сервера.
#Перед началом работы устанавливается защищённый канал, после чего пользователь может безопасно управлять системой.
