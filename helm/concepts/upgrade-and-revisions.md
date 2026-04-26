# Helm Upgrades and Revisions

Companion reading for [02-helm-upgrade-with-set-option.md](../02-helm-upgrade-with-set-option.md). This file explains the concepts behind `helm upgrade`, `--set`, and the revision history that powers `helm history`, `helm status`, and `helm rollback`.

## 1. Releases are mutable, revisions are immutable

There are two distinct ideas that beginners often conflate:

- **Release** — a *named, living instance* of a chart in your cluster (e.g. `myapp1`). It has one current state at any moment. You can change it: upgrade it, roll it back, uninstall it. That is what "mutable" means — the release moves through time.
- **Revision** — a *frozen snapshot* of what the release looked like at one point in time. Revision 1 is the install. Revision 2 is the first upgrade. Revision 3 is the second upgrade. Once written, a revision's manifests, values, and chart version never change. That is what "immutable" means.

A useful analogy: think of git.

- The **branch** = the release. It moves forward as you commit.
- Each **commit** = a revision. It is a fixed snapshot you can always check out again.

`helm upgrade` is the equivalent of `git commit` — it creates a new immutable point in history and advances the release pointer to it.

## 2. What actually happens during `helm upgrade`

When you run:

```bash
helm upgrade myapp1 stacksimplify/mychart1 --set "image.tag=2.0.0"
```

Helm performs roughly these steps:

1. **Render** the chart templates with the merged values (chart defaults + any `-f values.yaml` + any `--set` overrides). The result is a fully concrete set of Kubernetes manifests.
2. **Diff** the new manifests against the manifests stored in the *current* revision (revision 1).
3. **Apply** the diff to the cluster via the Kubernetes API. For a `Deployment` whose image tag changed, Kubernetes responds by:
   - creating a new ReplicaSet for `kubenginx:2.0.0`
   - rolling out new pods
   - scaling down the old ReplicaSet (pods running `1.0.0` are terminated)
4. **Write a new revision** (revision 2) into Helm's storage, containing the rendered manifests + values + chart metadata for *this* upgrade.
5. **Mark the old revision** (revision 1) as `superseded`. It is **not** deleted — it is kept around for history and rollback.

So at the cluster level, the old pod is gone. At the Helm level, the recipe that produced that old pod is still on disk.

## 3. Where revisions are stored

Helm 3 stores each revision as a Kubernetes **Secret** in the release's namespace, named:

```
sh.helm.release.v1.<release-name>.v<revision>
```

For our `myapp1` release after three upgrades you would see:

```bash
kubectl get secrets -l owner=helm
# sh.helm.release.v1.myapp1.v1
# sh.helm.release.v1.myapp1.v2
# sh.helm.release.v1.myapp1.v3
# sh.helm.release.v1.myapp1.v4
```

Each secret contains the gzipped, base64-encoded manifest + values for that revision. This is what makes rollback possible — Helm just re-applies an older secret's contents.

By default Helm keeps the **last 10 revisions**. Older ones are pruned. You can override this with the `--history-max` flag on `helm upgrade`.

## 4. The pod ≠ the revision

A common confusion: people think "the pod is the revision." It isn't.

- The **revision** is Helm's stored recipe.
- The **pod** is Kubernetes' running result of applying that recipe.

Pods can crash, get rescheduled, or be replaced by Kubernetes for reasons unrelated to Helm — the revision number does **not** change when that happens. The revision only changes when *you* run `helm upgrade` or `helm rollback`.

## 5. `--set` vs values files

The tutorial uses `--set "image.tag=2.0.0"` because it is the fastest way to override a single value during a demo. In practice there are three layers Helm merges, in order of increasing precedence:

1. The chart's own `values.yaml` (defaults shipped with the chart)
2. Any files passed with `-f my-values.yaml` (your environment-specific overrides)
3. Any `--set key=value` flags (highest precedence — wins over everything)

For real workloads you typically commit a `values-prod.yaml` file to git and use `-f`, reserving `--set` for one-offs and ad-hoc experiments. `--set` values are not stored in any file you control — they only live inside the Helm revision secret afterward.

You can always inspect what was actually applied:

```bash
# Just the user-supplied overrides for the current revision
helm get values myapp1

# All values, including chart defaults, for revision 2 specifically
helm get values myapp1 --revision 2 --all
```

## 6. Why immutability matters in practice

Because every revision is a complete, frozen snapshot:

- **`helm rollback myapp1 1`** works — Helm re-applies revision 1's stored manifests. Note that a rollback itself creates a *new* revision (e.g. revision 5) whose contents match revision 1. The history is append-only; you never overwrite the past.
- **`helm history myapp1`** can show exactly what was deployed at each revision because each one is a complete snapshot, not a delta.
- **`helm get manifest myapp1 --revision 2`** lets you see the exact YAML that was sent to Kubernetes at revision 2, even after you have moved on.
- **You cannot "edit" revision 2** after the fact. If you want different behavior, you do another `helm upgrade`, which creates revision N+1. This is what makes Helm a viable audit trail.

## 7. Release status across revisions

At any moment, each revision has a status:

- `deployed` — this is the currently active revision (only one revision can be `deployed` at a time)
- `superseded` — was active in the past, has since been replaced
- `failed` — the upgrade didn't apply cleanly
- `pending-upgrade` / `pending-install` — Helm is mid-operation
- `uninstalled` — set when `helm uninstall` runs (kept only if `--keep-history` was used)

`helm list` shows only `deployed` releases by default. To see superseded or failed ones:

```bash
helm list --superseded
helm list --failed
helm list --all
```

## 8. How this connects back to the tutorial

With the above in mind, the steps in [02-helm-upgrade-with-set-option.md](../02-helm-upgrade-with-set-option.md) become more meaningful:

| Tutorial step | What's really happening |
| --- | --- |
| `helm install myapp1 ...` | Creates release `myapp1`, writes revision 1 |
| `helm upgrade ... --set "image.tag=2.0.0"` | Renders new manifests, diffs, applies, writes revision 2, marks revision 1 as `superseded` |
| `helm list` showing `REVISION: 2` | Confirms the release pointer advanced |
| `kubectl describe pod` showing the new image | Confirms Kubernetes acted on the diff |
| `helm history myapp1` | Reads back all stored revision secrets |
| `helm status myapp1 --revision 2` | Reads back the snapshot for that one revision |
| `helm uninstall myapp1` | Deletes all revision secrets and the cluster resources they own |

## 9. Quick reference: useful commands not in the tutorial

```bash
# See the user-supplied values at the current revision
helm get values myapp1

# See the fully-merged values (defaults + overrides) at a specific revision
helm get values myapp1 --revision 2 --all

# See the rendered Kubernetes YAML for a revision
helm get manifest myapp1 --revision 2

# Roll back to a previous revision (creates a new revision pointing at old content)
helm rollback myapp1 1

# Limit how many revisions Helm keeps (default is 10)
helm upgrade myapp1 stacksimplify/mychart1 --set "image.tag=2.0.0" --history-max 5

# Preview what an upgrade would change without applying it
helm upgrade myapp1 stacksimplify/mychart1 --set "image.tag=2.0.0" --dry-run
```
