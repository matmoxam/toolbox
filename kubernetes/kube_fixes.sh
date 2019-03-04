# Fx for core DNS constant restarts
kubectl -n kube-system get deployment coredns -o yaml | sed 's/allowPrivilegeEscalation: false/allowPrivilegeEscalation: true/g' | kubectl apply -f -

# Busy Box for debugging
kubectl run -it --rm --restart=Never busybox --image=busybox sh
