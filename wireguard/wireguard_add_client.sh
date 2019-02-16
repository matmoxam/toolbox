#!/bin/bash

# Get server config values
SERVER_PORT=`cat /etc/wireguard/server_port.txt`
SERVER_VPN_IP=`cat /etc/wireguard/server_pub_ip.txt`
SERVER_PUBLIC_IP=`cat /etc/wireguard/endpoint.txt`
SERVER_PUBKEY=`cat /etc/wireguard/publickey`
typeset -i NUM_CLIENTS=`cat /etc/wireguard/num_peers.txt`
let "NUM_CLIENTS++"


SERVER_VPN_IP_CUT=${SERVER_VPN_IP%?}
CLIENT_VPN_IP=$SERVER_VPN_IP_CUT$NUM_CLIENTS
echo "Client IP will be: " $CLIENT_VPN_IP

CLIENT=
echo -n "Enter name of client to add > "
read CLIENT

# Check if client already exists 
if [ -d "/etc/wireguard/peers/$CLIENT" ]; then
  echo "The client $CLIENT already exists. Please rerun and use a different client name..."
  exit 1
fi

echo "Creating new configs for $CLIENT ..."
mkdir /etc/wireguard/peers/$CLIENT
cd /etc/wireguard/peers/$CLIENT

# Generate the private and public keys for the client
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
PRIVKEY=`cat privatekey`
PUBKEY=`cat publickey`
echo "$PRIVKEY"
echo "$PUBKEY"

# Create the wireguard VPN client config file
tee -a /etc/wireguard/peers/$CLIENT/wg0.conf << END
[Interface]
#Address = $CLIENT_VPN_IP/24
PrivateKey = $PRIVKEY
ListenPort = $SERVER_PORT
#DNS = $SERVER_VPN_IP

[PEER]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
PersistentKeepalive = 21  
END

# Create the wireguard VPN client up file
tee -a /etc/wireguard/peers/$CLIENT/wg-up.sh << END
ip link add dev wg0 type wireguard
ip addr add $CLIENT_VPN_IP/24 dev wg0
wg addconf wg0 /etc/wireguard/wg0.conf
ip link set wg0 up
END

# Create the wireguard VPN client service file
tee -a /etc/wireguard/peers/$CLIENT/wireguard.service << END
# Place file at: /etc/systemd/system/wireguard.service
# Run systemctl daemon-reload
[Unit]
Description = Wireguard Client Service
After = network.target

[Service]
type=oneshot
PIDFile = /run/wireguard_client/wireguard_client.pid
User = root
Group = root
WorkingDirectory = /etc/wireguard
ExecStart = /etc/wireguard/wg-up.sh
ExecStartPost = ping -c2 10.7.0.1
ExecStop = /sbin/ip link del dev wg0

[Install]
WantedBy = multi-user.target 
END

# Add this client to the server
wg set wg0 peer $PUBKEY allowed-ips $CLIENT_VPN_IP/32

# Save server config
wg-quick save wg0

# Increase the counter for number of added clients
echo "Incrementing total client count to $NUM_CLIENTS"
echo "$NUM_CLIENTS" > /etc/wireguard/num_peers.txt
