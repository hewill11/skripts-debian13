#!/bin/bash

apt update -y
apt install -y openssh-server

useradd -m student
echo "student:1" | chpasswd

systemctl enable ssh
systemctl restart ssh
