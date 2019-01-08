# Turn off swap
swapoff -a

# Install docker
yum -y install docker, net-tools, nano
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

# Manaully make the following changes
echo "Edit /etc/fstab and comment out the line that causes swap. Example #/root/swap"
echo "Edit /etc/selinux/config and change SELINUX=enforcing to SELINUX=permissive"
echo "Run the Kubectl join command issued by the master to attach this node to the cluster"
