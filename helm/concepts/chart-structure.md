# Helm Chart Folder Structure — Deep Dive

Supporting knowledge for [../05-Helm-Chart-Structure.md](../05-Helm-Chart-Structure.md). Source slides: `Helm Chart - Folder Structure.pdf` (Kalyan Reddy Daida).

When you run `helm create basechart`, Helm scaffolds a directory that is part **manifest source**, part **metadata**, and part **distribution packaging**. Each file/folder has a precise role — Helm itself looks for these by name, so the layout is convention-bound, not arbitrary.

```
basechart/
├── .helmignore
├── Chart.yaml
├── LICENSE
├── README.md
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
│       └── test-connection.yaml
└── values.yaml
```

---

## 1. `Chart.yaml` — chart metadata

The identity card of the chart. Helm refuses to install a directory that lacks this file.

```yaml
apiVersion: v2          # v2 = Helm 3 charts. v1 = legacy Helm 2.
name: basechart         # chart name; must match the directory name
description: my basechart
type: application       # 'application' (deployable) or 'library' (reusable templates only)
version: 0.1.0          # the CHART version — bumped when chart files change (SemVer)
appVersion: "1.0.0"     # the APP version — the version of the software the chart deploys
```

**Why two versions?**
- `version` tracks the chart itself — bump it when you edit templates, values, or dependencies.
- `appVersion` tracks the underlying app (e.g. nginx 1.25.3). You can ship many `version` revisions of the chart against the same `appVersion`.

Other optional keys you'll meet later: `dependencies:`, `keywords:`, `maintainers:`, `icon:`, `kubeVersion:`.

---

## 2. `values.yaml` — default configuration

The default knobs for the chart's templates. Anything templated as `{{ .Values.foo }}` resolves here unless overridden.

Override precedence (lowest → highest):
1. `values.yaml` inside the chart
2. `-f myvalues.yaml` (one or more files; later files win)
3. `--set key=value` on the command line
4. `--set-file` / `--set-string` variants

This is the same override mechanism you used in `02-helm-upgrade-with-set-option.md`.

A library chart has no `values.yaml`. An application chart usually does, even if empty.

---

## 3. `charts/` — subchart dependencies

The *inner* `charts/` (inside the chart directory) is reserved for **other charts that this chart depends on**. Don't confuse it with a workspace `charts/` you might create to hold multiple unrelated charts you're learning with.

Two ways subcharts get here:

**Manual** — drop another chart's directory or `.tgz` tarball directly into `charts/`.

**Declared** — list dependencies in `Chart.yaml` and let Helm fetch them:

```yaml
# Chart.yaml
dependencies:
  - name: mysql
    version: "9.x.x"
    repository: "https://charts.bitnami.com/bitnami"
```

```bash
helm dependency update    # populates charts/ from the repository
helm dependency build     # rebuilds charts/ from Chart.lock (reproducible)
```

**Classic example (from the slides):** a "UMS App" parent chart that depends on a `mysql` subchart. Installing the parent installs both — values flow from the parent's `values.yaml` into the subchart under a key matching the subchart's name.

---

## 4. `templates/` — the rendering engine input

Every file here (with two exceptions noted below) is run through Go's `text/template` engine, combined with `.Values`, `.Chart`, `.Release`, and other built-in objects, then sent to the cluster as a Kubernetes manifest.

**Mental model:** `templates/` + `values.yaml` → rendered YAML → `kubectl apply`.

If you already have raw Kubernetes manifests, "Helm-ifying" them is mostly:
1. Move them into `templates/`.
2. Replace hard-coded values with `{{ .Values.something }}`.
3. Add `{{ include "basechart.labels" . }}` for consistent labels.

### 4a. `templates/deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`, `serviceaccount.yaml`

Standard Kubernetes resource templates that `helm create` generates. Each is gated by values so you can disable what you don't need:

```yaml
# values.yaml
ingress:
  enabled: false
autoscaling:
  enabled: false
serviceAccount:
  create: true
```

The templates wrap their bodies in `{{- if .Values.ingress.enabled }} ... {{- end }}`, so disabling them produces no manifest at all — not an empty object.

### 4b. `templates/_helpers.tpl` — partials, not manifests

Files starting with `_` are **excluded** from manifest output. Helm still renders them, but only to register the `define` blocks inside, which other templates pull in via `include`.

```gotemplate
{{/*
Selector labels
*/}}
{{- define "basechart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "basechart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Then in `deployment.yaml`:

```yaml
selector:
  matchLabels:
    {{- include "basechart.selectorLabels" . | nindent 6 }}
```

This is how DRY works in Helm — define once, include everywhere.

### 4c. `templates/NOTES.txt` — post-install message

Optional, but every scaffolded chart ships one. It's templated like any other file, but its rendered output is **printed to your terminal** after `helm install` / `helm upgrade` instead of being applied to the cluster.

Typical use: tell the user how to reach the app they just installed.

```gotemplate
{{- if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get svc {{ include "basechart.fullname" . }} -o jsonpath="{.spec.ports[0].nodePort}")
  export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- end }}
```

Because it's a normal template, you have full access to `.Values`, `.Chart`, `.Release`, conditionals, pipelines, functions — anything the manifest templates can do.

### 4d. `templates/tests/` — chart smoke tests

Manifests with the annotation `helm.sh/hook: test` go here. They are **not** applied during `helm install` — they run only when you invoke:

```bash
helm test <RELEASE-NAME>
```

`helm test` creates the test pod, waits for it to terminate, and reports pass/fail based on exit code.

Two purposes:
- **Validate**: confirm the release is functional (service resolves, app responds on its port, DB is reachable).
- **Document**: a chart consumer can read the tests to see what "working" means for this chart.

The default `test-connection.yaml` runs `wget` against the service — minimal, but a real example.

---

## 5. `.helmignore` — packaging exclusions

When you run `helm package basechart`, Helm tars up the directory into `basechart-0.1.0.tgz` for distribution. `.helmignore` works like `.gitignore` and keeps junk out of that tarball: `.git/`, IDE files, OS metadata, `*.swp`, etc.

It does **not** affect rendering — only what ends up in the package.

---

## 6. `README.md` — human documentation

How to install, configure, and operate the chart. Common sections:
- Prerequisites (Kubernetes version, ingress controller, etc.)
- Installation command
- Configuration table (every value in `values.yaml` with description and default)
- Upgrade notes
- Uninstall steps

Chart repositories like Artifact Hub render this README on the chart's page.

---

## 7. `LICENSE` — usage terms

Plain-text license file (MIT, Apache-2.0, etc.). Especially relevant when publishing the chart to a public repo so consumers know the terms of use.

---

## Files Helm creates that aren't in the slide deck

For completeness, you'll also encounter these once you start working with dependencies and packaging:

| File | When it appears | Purpose |
|---|---|---|
| `Chart.lock` | After `helm dependency update` | Pins resolved subchart versions, like `package-lock.json`. Commit it. |
| `requirements.yaml` / `requirements.lock` | Helm 2 legacy | Equivalent of `dependencies:` in `Chart.yaml`. Don't use in new charts. |
| `values.schema.json` | Optional, you create it | JSON Schema validation for `values.yaml` — Helm rejects bad values at install time. |
| `crds/` | Optional, you create it | Raw CRD YAML installed *before* templates render. Not templated. |

---

## Quick reference: who reads what?

| Path | Read by | When |
|---|---|---|
| `Chart.yaml` | Helm | Every command — identifies the chart |
| `values.yaml` | Helm template engine | Every render |
| `templates/*.yaml` | Helm template engine → kubectl | `install`, `upgrade`, `template` |
| `templates/_*.tpl` | Helm template engine | Render time, never emitted |
| `templates/NOTES.txt` | Helm | Render time; printed to stdout |
| `templates/tests/` | Helm | Only on `helm test` |
| `charts/` | Helm | Render time, as subcharts |
| `.helmignore` | Helm | `helm package` only |
| `README.md`, `LICENSE` | Humans, chart repos | Browsing / publishing |

---

## Related reading in this repo

- [01-helm-install.md](../01-helm-install.md) — installing a chart
- [02-helm-upgrade-with-set-option.md](../02-helm-upgrade-with-set-option.md) — overriding `values.yaml`
- [03-Helm-Upgrade-with-Chart-Versions.md](../03-Helm-Upgrade-with-Chart-Versions.md) — bumping `Chart.yaml: version`
- [release.md](release.md) — what a release is
- [upgrade-and-revisions.md](upgrade-and-revisions.md) — revision history mechanics
