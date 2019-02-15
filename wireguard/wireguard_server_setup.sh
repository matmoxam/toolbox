SERVER_PORT=47876
SERVER_VPN_IP=10.7.0.1
SERVER_PUBLIC_IP=
PUBLIC_ETH=

# Get public ip address of server (eth0 normally)
echo -n "Enter the public ipaddress of this server > "
read SERVER_PUBLIC_IP

# Get public ip address interface of server (eth0 normally)
echo -n "Enter the public interface to be used for this server. eg. eth0 > "
read PUBLIC_ETH

# Install all needed binaries for centos7
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
#yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
#yum -y install epel-release dkms wireguard-dkms wireguard-tools

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
systemctl daemon-reload

# Create the Wireguard config folder
mkdir /etc/wireguard
cd /etc/wireguard
mkdir /etc/wireguard/peers

# Generate the private and public keys for the VPN server
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
PRIVKEY=`cat privatekey`
PUBKEY=`cat publickey`
echo "$PRIVKEY"
echo "$PUBKEY"

# Create the wireguard VPN server config file
tee -a /etc/wireguard/wg0.conf << END
[Interface]
Address = $SERVER_VPN_IP/24
PrivateKey = $PRIVKEY
ListenPort = $SERVER_PORT
SaveConfig = true
# Change eth0 to the public facing interface if eth0 is not the public interface
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $PUBLIC_ETH -j MASQUERADE; iptables -A INPUT -p udp -m udp --dport $SERVER_PORT -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $PUBLIC_ETH -j MASQUERADE; iptables -D INPUT -p udp -m udp --dport $SERVER_PORT -j ACCEPT
END

sysctl net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-sysctl.conf

# Write all needed variables to files
echo "$SERVER_PUBLIC_IP" > /etc/wireguard/endpoint.txt
echo "1" > /etc/wireguard/num_peers.txt
echo "$SERVER_PORT" > /etc/wireguard/server_port.txt
echo "$SERVER_VPN_IP" > /etc/wireguard/server_pub_ip.txt

# Auto start and enable wiregaurd VPN server
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service


# DNS server install to prevent DNS leaks
yum -y update
yum -y install unbound

# Backup original config file
cp /etc/unbound/unbound.conf /etc/unbound/unbound.conf.original

# Create new unbound config
tee /etc/unbound/unbound.conf << END
server:	
	verbosity: 1
	statistics-interval: 0	
	statistics-cumulative: no	
	extended-statistics: yes	
	num-threads: 4	
	interface: 10.7.0.1	
	interface-automatic: no	
	port: 53	
	so-reuseport: yes	
	ip-transparent: yes	
	do-ip4: yes	
	do-ip6: yes	
	do-udp: yes	
	do-tcp: yes	
	access-control: 0.0.0.0/0 allow
	chroot: ""	
	username: "unbound"	
	directory: "/etc/unbound"	
	logfile: "/var/log/unbound"	
	log-time-ascii: yes	
	pidfile: "/var/run/unbound/unbound.pid"	
	hide-identity: yes	
	hide-version: yes	
	harden-glue: yes	
	harden-dnssec-stripped: yes	
	harden-below-nxdomain: yes	
	harden-referral-path: yes	
	unwanted-reply-threshold: 10000000	
	prefetch: yes	
	prefetch-key: yes	
	rrset-roundrobin: yes	
	minimal-responses: yes	
	module-config: "ipsecmod validator iterator"	
	trust-anchor-signaling: yes	
	trusted-keys-file: /etc/unbound/keys.d/*.key
	auto-trust-anchor-file: "/var/lib/unbound/root.key"	
	val-clean-additional: yes
	val-permissive-mode: no
	val-log-level: 1
	include: /etc/unbound/local.d/*.conf	
	ipsecmod-enabled: no	
	ipsecmod-hook: "/usr/libexec/ipsec/_unbound-hook"

python:
remote-control:	
	control-enable: yes	
	server-key-file: "/etc/unbound/unbound_server.key"	
	server-cert-file: "/etc/unbound/unbound_server.pem"	
	control-key-file: "/etc/unbound/unbound_control.key"	
	control-cert-file: "/etc/unbound/unbound_control.pem"

include: /etc/unbound/conf.d/*.conf

 forward-zone:
 	name: "."
 	forward-addr: 1.1.1.1
END

systemctl start unbound.service
systemctl enable unbound.service

