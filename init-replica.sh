#!/bin/bash 

#**************************************************************************************************************************
ASTRA_BASE="http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.4/repository-base"
ASTRA_EXT="http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.4/repository-extended"

ALD_VERSION="2.2.0"
ALD_MAIN="https://dl.astralinux.ru/aldpro/frozen/01/2.2.0 1.7_x86-64 main base"

HOSTNAME_NEW="dc01.local.domain"
DOMAIN="local.domain"
IPV4="172.26.71.221"
MASK="255.255.255.0"
GATEWAY="172.26.71.1"

# Domain controller IP-address
NAMESERVERS="172.26.71.220"
PASSWORD_ADMIN=""

#**************************************************************************************************************************

cat <<EOL > /etc/apt/sources.list
deb $ASTRA_BASE 1.7_x86-64 main non-free contrib
EOL

#Добавление репозиториев ALD Pro
cat <<EOL > /etc/apt/sources.list.d/aldpro.list
deb $ALD_MAIN $ALD_VERSION main
EOL

#Установка приоритетов репозиториев
cat <<EOL > /etc/apt/preferences.d/aldpro
Package: *
Pin: release n=generic
Pin-Priority: 900
EOL

#Настройка hostname
hostnamectl set-hostname $HOSTNAME_NEW 
NAME=`awk -F"." '{print $1}' /etc/hostname`


#Настройка сети
systemctl stop NetworkManager
systemctl disable NetworkManager
systemctl stop  NetworkManager

ip addr flush dev eth0
systemctl enable networking

cat <<EOL > /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address $IPV4
  netmask $MASK
  gateway $GATEWAY
  dns-nameservers $NAMESERVERS
  dns-search $DOMAIN
EOL

#Настройка /etc/hosts
cat <<EOL > /etc/hosts
127.0.0.1 localhost.localdomain localhost
$IPV4 $HOSTNAME_NEW $NAME
EOL

#Настройка /etc/resolv.conf
cat <<EOL > /etc/resolv.conf
search $DOMAIN
nameserver $NAMESERVERS
EOL

systemctl restart networking

apt update && apt list --upgradable && apt dist-upgrade -y -o Dpkg::Options::=--force-confnew

sleep 10

LEVEL=$(astra-modeswitch get)
if [[ $LEVEL -ne 2 ]]
then  
    astra-modeswitch set 2
    astra-mic-control enable
    astra-mac-control enable
fi


DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-client

systemctl restart networking

/opt/rbta/aldpro/client/bin/aldpro-client-installer -c $DOMAIN  -u admin -p $PASSWORD_ADMIN -d $NAME -i -f 


sleep 10
reboot