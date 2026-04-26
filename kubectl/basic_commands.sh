
# Verify kubectl is installed and working
kubectl version --client

# List config contexts
kubectl config get-contexts

# Config Current context
kubectl config current-context

# Check cluster info
kubectl cluster-info --context kind-helm-practice

