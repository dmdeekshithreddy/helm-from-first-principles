# Helm Install

## Step-01: Introduction

- We will use the following commands as part of this demo
- helm repo list
- helm repo add
- helm repo update
- helm search repo
- helm install
- helm list
- helm uninstall

## Step-02: List, Add and Search Helm Repository

- [Bitnami Applications packaged using Helm](https://bitnami.com/stacks/helm)
- [Search for Helm Charts at Artifacthub.io](https://artifacthub.io/)

```bash
# List Helm Repositories
helm repo list

# Add Helm Repository
helm repo add <DESIRED-NAME> <HELM-REPO-URL>
helm repo add mybitnami https://charts.bitnami.com/bitnami

# List Helm Repositories
helm repo list

# Search Helm Repository
helm search repo <KEY-WORD>
helm search repo nginx
helm search repo apache
helm search repo wildfly

# Search Helm Repository for a specific chart version
helm seach repo nginx --version 23.0.3
```

## Step-03: Install Helm Chart

- Installs the Helm Chart

```bash
# Update Helm Repo
helm repo update  # Make sure we get the latest list of charts

# Install Helm Chart
helm install <RELEASE-NAME> <repo_name_in_your_local_desktop/chart_name>
helm install mynginx mybitnami/nginx
```

> See [Helm Release concepts](concepts/release.md) for what `RELEASE-NAME` means and why it matters.

> **Note: `helm repo update` is analogous to `apt update`**
>
> `helm repo update` refreshes the local cache of chart metadata from all the Helm repos you've added (via `helm repo add`), so `helm search` and `helm install` see the latest available chart versions.
>
> - `apt update` → refreshes package lists from configured APT sources (`/etc/apt/sources.list`)
> - `helm repo update` → refreshes chart indexes from configured Helm repos (`~/.config/helm/repositories.yaml`)
>
> Neither command installs or upgrades anything — they just sync metadata. The Helm equivalent of `apt upgrade` would be `helm upgrade <release>` (per release, not bulk).
>
> One small distinction: `apt update` pulls from sources defined system-wide, while Helm repos are per-user by default.

## Step-04: List Helm Releases

- This command lists all of the releases for a specified namespace

```bash
# List Helm Releases (Default Table Output)
helm list
helm ls

# List Helm Releases (YAML Output)
helm list --output=yaml

# List Helm Releases (JSON Output)
helm list --output=json

# List Helm Releases with namespace flag
helm list --namespace=default
helm list -n default
```

## Step-05: List Kubernetes Resources

```bash
# List Kubernetes Pods
kubectl get pods

# List Kubernetes deployments


# List Kubernetes Services
kubectl get svc
Observation: Review the EXTERNAL-IP field and you will see it as localhost. Access the nginx page from local desktop localhost

# Access Nginx Application on local desktop browser
http://localhost:80
http://127.0.0.1:80

# Access Application using curl command
curl http://localhost:80
curl http://127.0.0.1:80
```

## Step-06: Uninstall Helm Release - NO FLAGS

```bash
# List Helm Releases
helm ls

# Uninstall Helm Release
helm uninstall <RELEASE-NAME>
helm uninstall mynginx
```
