#!/bin/bash 

#**************************************************************************************************************************

ASTRA_BASE="http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.4/repository-base"
ASTRA_EXT="http://download.astralinux.ru/astra/frozen/1.7_x86-64/1.7.4/repository-extended"

ALD_VERSION="2.2.0"
ALD_MAIN="https://dl.astralinux.ru/aldpro/frozen/01/2.2.0 1.7_x86-64 main base"

HOSTNAME="dc01.local.domain"
DOMAIN="local.domain"
IPV4="172.26.71.220"
MASK="255.255.255.0"
GATEWAY="172.26.71.1"

NAMESERVERS="8.8.8.8"
PASSWORD_ADMIN=""

#**************************************************************************************************************************

cat <<EOL > /etc/apt/sources.list
deb $ASTRA_BASE 1.7_x86-64 main non-free contrib
deb $ASTRA_EXT 1.7_x86-64 main contrib non-free
EOL

cat <<EOL > /etc/apt/sources.list.d/aldpro.list
deb $ALD_MAIN $ALD_VERSION main
EOL

cat <<EOL > /etc/apt/preferences.d/aldpro
Package: *
Pin: release n=generic
Pin-Priority: 900
EOL

hostnamectl set-hostname $HOSTNAME 
NAME=`awk -F"." '{print $1}' /etc/hostname`

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

cat <<EOL > /etc/hosts
127.0.0.1 localhost.localdomain localhost
$IPV4 $HOSTNAME $NAME
EOL

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

DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-mp aldpro-gc aldpro-syncer


cat <<EOL > /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address $IPV4
netmask $MASK
gateway $GATEWAY
dns-nameservers 127.0.0.1
dns-search $DOMAIN
EOL

cat <<EOL > /etc/resolv.conf
search $DOMAIN
nameserver 127.0.0.1
EOL

systemctl restart networking

aldpro-server-install -d $DOMAIN  -p $PASSWORD_ADMIN -n $NAME --ip $IPV4  --setup_syncer --setup_gc --no-reboot

echo $PASSWORD_ADMIN | kinit admin
ipa group-add-member 'ald trust admin' --users=admin

sleep 10
reboot