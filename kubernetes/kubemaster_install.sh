# Get ip address to use for this master
NODE_IP=
echo -n "Enter the ipaddress of this master > "
read NODE_IP

# Turn off firewall
systemctl stop firewalld
systemctl disable firewalld

# Add hostname to local dns
echo "127.0.0.1" $HOSTNAME >> /etc/hosts

# Turn off swap
swapoff -a

# Install docker
#yum -y install docker net-tools nano
yum -y install net-tools nano yum-utils device-mapper-persistent-data lvm2
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
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl --system

echo "KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP" > /etc/sysconfig/kubelet

# Install all kubernetes containers via kubeadm and set kubernetes subnet
#kubeadm init --pod-network-cidr=10.244.0.0/16 > kubeadm_init.log
#kubeadm init --apiserver-advertise-address=0.0.0.0 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors all
kubeadm init --apiserver-advertise-address=$NODE_IP --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Install overlay network in this case flannel or weave or kube-router
#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml

# Install metallb, traefik ingress controller and cert-manager
kubectl apply -f https://raw.githubusercontent.com/matmoxam/toolbox/master/kubernetes/metallb_config.yml
kubectl apply -f https://raw.githubusercontent.com/matmoxam/toolbox/master/kubernetes/traefik-kube-install.yml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/cert-manager.yaml

kubectl get nodes

# Manaully make the following changes
echo "nano /etc/fstab and comment out the line that causes swap. Example #/root/swap"
