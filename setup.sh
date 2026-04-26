# install kind; 
## kind is a tool for running local Kubernetes clusters using Docker container "nodes". 
## It is primarily designed for testing Kubernetes itself, but may be used for local development or CI.
brew install kind

# create a directory for the project and navigate into it
mkdir helm-practice && cd helm-practice

# create a config file for kind cluster
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# create a cluster with a config file
kind create cluster --name helm-practice --config ~/helm-practice/kind-config.yaml

# check cluster status
kind get clusters
# check nodes
kubectl get nodes

# install helm;
## Helm is a package manager for Kubernetes that helps you manage Kubernetes applications.
brew install helm

# Stop the cluster when you are done
docker stop $(docker ps --filter "label=io.x-k8s.kind.cluster" -q)
## or
docker stop $(kind get nodes --name=helm-practice -o name)

# Start the cluster again
docker start $(docker ps -a --filter "label=io.x-k8s.kind.cluster" -q)
## or
docker start $(kind get nodes --name=helm-practice -o name)


