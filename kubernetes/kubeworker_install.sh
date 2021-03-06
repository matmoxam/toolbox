# Get ip address to use for this node
NODE_IP=
echo -n "Enter the ipaddress of this node > "
read NODE_IP

# Turn off firewall
systemctl stop firewalld
systemctl disable firewalld

# Add hostname to local dns
echo "127.0.0.1" $HOSTNAME >> /etc/hosts
#echo "127.0.0.1" $NODE_IP >> /etc/hosts

# Turn off swap
swapoff -a

# Install docker
#yum -y install docker net-tools nano
yum -y install yum-utils device-mapper-persistent-data lvm2 net-tools nano
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce-18.06.1.ce-3.el7
systemctl enable docker
systemctl start docker

# Add kubernetes repo
cat << EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Turn off SELINUX
setenforce 0
sed 's/^SELINUX=enforcing.*/SELINUX=permissive/g' /etc/selinux/config > config
mv -f config /etc/selinux/config
rm config

# Install kubernetes binaries
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl start kubelet

# Edit kubernetes config to support IP6
cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

# Set the Ip of this node to kubelet config
echo "KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP" > /etc/sysconfig/kubelet

# Manaully make the following changes
echo "nano /etc/fstab and comment out the line that causes swap. Example #/root/swap"
echo "Run the Kubectl join command issued by the master to attach this node to the cluster"
