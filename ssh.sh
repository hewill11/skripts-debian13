#!/bin/bash

apt update -y
apt install -y openssh-server

useradd -m student
echo "student:1" | chpasswd

systemctl enable ssh
systemctl restart ssh

#SSH — это защищённый протокол удалённого доступа, который использует шифрование, аутентификацию и проверку подлинности сервера.
#Перед началом работы устанавливается защищённый канал, после чего пользователь может безопасно управлять системой.
