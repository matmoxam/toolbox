#!/bin/bash

if [ -d "/etc/wireguard" ]; then
  echo "The wireguard directory (/etc/wireguard/) already exists... Please cleanup previous configurations first..."
  exit 1
fi

# Install all needed binaries for centos7
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
#yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#yum -y install epel-release dkms wireguard-dkms wireguard-tools
yum -y install wget

mkdir /opt/wireguard
cd /opt/wireguard

KERNEL_VER="$(uname -r)"
wget http://ftp.riken.jp/Linux/scientific/7.0/x86_64/updates/security/kernel-devel-$KERNEL_VER.rpm
wget http://ftp.riken.jp/Linux/scientific/7.0/x86_64/updates/security/kernel-headers-$KERNEL_VER.rpm
yum -y install epel-release nano wget gcc
yum -y install libmnl-devel elfutils-libelf-devel pkg-config @development-tools
yum -y install kernel-devel-$KERNEL_VER.rpm
yum -y install kernel-headers-$KERNEL_VER.rpm
yum -y install dkms wireguard-dkms wireguard-tools
wget https://git.zx2c4.com/WireGuard/snapshot/WireGuard-0.0.20190123.tar.xz
tar -xvf /opt/wireguard/WireGuard-0.0.20190123.tar.xz
cd /opt/wireguard/WireGuard-0.0.20190123/src
make
make install

# Install resolverconf for dns
cd /etc/yum.repos.d
wget https://copr.fedorainfracloud.org/coprs/macieks/openresolv/repo/epel-7/macieks-openresolv-epel-7.repo
yum -y update
yum -y install openresolv traceroute

systemctl daemon-reload

#cp wg0.conf /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0.service
mkdir /etc/wireguard
     
if [ -f /etc/wireguard/wg0.conf ]; then  
  # Auto start and enable wiregaurd VPN server
  systemctl start wg-quick@wg0.service  
else
   echo "/etc/wireguard/wg0.conf does not exist. Get this file from the VPN server..."
   exit 1
fi
