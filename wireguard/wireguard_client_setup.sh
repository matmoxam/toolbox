#!/bin/bash

if [ -d "/etc/wireguard" ]; then
  echo "The wireguard directory (/etc/wireguard/) already exists... Please cleanup previous configurations first..."
  exit 1
fi

CLIENT_VPN_IP=
echo -n "Enter the VPN IP address this client will use. eg. 10.7.0.N > "
read CLIENT_VPN_IP

# Install all needed binaries for centos7
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
yum -y install epel-release nano wget gcc

mkdir /opt/wireguard
cd /opt/wireguard

KERNEL_VER="$(uname -r)"
wget http://ftp.riken.jp/Linux/scientific/7.0/x86_64/updates/security/kernel-devel-$KERNEL_VER.rpm
wget http://ftp.riken.jp/Linux/scientific/7.0/x86_64/updates/security/kernel-headers-$KERNEL_VER.rpm
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

mkdir /etc/wireguard

# Create the wireguard VPN client up file
#tee -a /etc/wireguard/wg-up.sh << END
#/sbin/ip link add dev wg0 type wireguard
#/sbin/ip addr add $CLIENT_VPN_IP/24 dev wg0
#/bin/wg addconf wg0 /etc/wireguard/wg0.conf
#/sbin/ip link set wg0 up
#END

# Create the wireguard VPN client service file
tee -a /etc/systemd/system/wireguard.service << END
# Place file at: /etc/systemd/system/wireguard.service
# Run systemctl daemon-reload
[Unit]
Description = Wireguard Client Service
After = network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory = /etc/wireguard
ExecStartPre = /sbin/ip link add dev wg0 type wireguard
ExecStartPre = /sbin/ip addr add $CLIENT_VPN_IP/24 dev wg0
ExecStartPre = /bin/wg addconf wg0 /etc/wireguard/wg0.conf
ExecStart = /sbin/ip link set wg0 up
ExecStartPost = ping -c2 10.7.0.1
ExecStop = /sbin/ip link del dev wg0

[Install]
WantedBy = multi-user.target 
END

systemctl daemon-reload
systemctl enable wireguard.service


