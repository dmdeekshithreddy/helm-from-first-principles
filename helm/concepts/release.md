# Helm Release

A **release** is an *instance* of a chart running in your cluster. The `RELEASE-NAME` is the unique label you give that instance, scoped to a namespace.

```bash
helm install mynginx mybitnami/nginx
#            ^^^^^^^ this is the release name
```

## Why it matters

### 1. You can install the same chart multiple times

Each install needs a distinct release name:

```bash
helm install nginx-frontend  mybitnami/nginx
helm install nginx-internal  mybitnami/nginx
helm install nginx-staging   mybitnami/nginx
```

All three are separate releases of the *same* chart, running side-by-side.

### 2. It's the handle for every follow-up command

Helm tracks releases by name — you reference them in:

```bash
helm upgrade   mynginx mybitnami/nginx   # upgrade this release
helm rollback  mynginx 1                 # roll back this release
helm status    mynginx                   # inspect this release
helm uninstall mynginx                   # delete this release
```

### 3. It prefixes the Kubernetes resources Helm creates

Charts typically template resource names as `{{ .Release.Name }}-something`. So `helm install mynginx ...` may create a Deployment called `mynginx-nginx`, a Service called `mynginx-nginx`, etc. This is what lets two releases of the same chart coexist without colliding.

### 4. Scope is per-namespace

Release names must be unique *within a namespace*, not cluster-wide. You can have `mynginx` in `dev` and `mynginx` in `prod`.

## Auto-generated names

If you don't want to think of one, let Helm pick:

```bash
helm install mybitnami/nginx --generate-name
# creates something like: nginx-1714125600
```
