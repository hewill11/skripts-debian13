#!/bin/bash

#Команды для времени
timedatectl list-timezones | grep Asia
timedatectl set-timezone Asia/Krasnoyarsk

#Имя через nmtui меняй