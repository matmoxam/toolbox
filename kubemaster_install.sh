# Turn off swap
swapoff -a

# Install docker
yum -y install docker net-tools nano
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

# Install all kubernetes containers via kubeadm and set kubernetes subnet
kubeadm init --pod-network-cidr=10.244.0.0/16 > kubeadm_init.log
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Install overlay network in this case flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml

kubectl get nodes

# Manaully make the following changes
echo "nano /etc/fstab and comment out the line that causes swap. Example #/root/swap"
