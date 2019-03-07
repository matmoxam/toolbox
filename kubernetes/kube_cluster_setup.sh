# Install metallb, traefik ingress controller and cert-manager
kubectl apply -f https://raw.githubusercontent.com/matmoxam/toolbox/master/kubernetes/metallb_config.yml
kubectl apply -f https://raw.githubusercontent.com/matmoxam/toolbox/master/kubernetes/traefik-kube-install.yml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/cert-manager.yaml
