# openshift-rhcos-rpm-versions

Fetch the list of RPM packages installed in the RHEL CoreOS (RHCOS) node
image for OpenShift Container Platform (OCP) releases, so package versions
can be compared across OCP versions.

Since OCP 4.12, RHCOS ships as the `rhel-coreos` image (CoreOS layering)
instead of the old `machine-os-content` image, and no longer bundles a
`/pkglist.txt` file. These scripts resolve the `rhel-coreos` image for a
given release via `oc adm release info --image-for=rhel-coreos` and list
its packages with `rpm -qa`.

## Requirements

- `oc` and `podman`, authenticated to pull `quay.io/openshift-release-dev/ocp-v4.0-art-dev`
- A pull secret authfile (default: `$HOME/.config/containers/auth.json`,
  override with `AUTHFILE`)

## Files

- `lib-rhcos-rpm-versions.sh` — shared library exposing `fetch_rhcos_rpm_versions <version> <output_file>`
- `fetch-rhcos-rpm-versions.sh` — fetch the RPM list for a single OCP version
- `fetch-rhcos-rpm-versions-range.sh` — fetch RPM lists for all GA z-stream releases across a range of minor versions

## Usage

### Single version

```bash
OCP_VERSION=4.22.5 ./fetch-rhcos-rpm-versions.sh
```

Writes `ocp-4.22.5-rhcos-rpms.txt` in the current directory (override with `OUTPUT_FILE`).

### A range of versions

```bash
./fetch-rhcos-rpm-versions-range.sh
```

Discovers every GA z-stream release for minors 4.16–4.22 from the
OpenShift mirror, then fetches each one (newest first) that hasn't already
been fetched. Output goes to `outputs/<minor>/ocp-<version>-rhcos-rpms.txt`.

Environment variables:

| Variable        | Default    | Description                                              |
|-----------------|------------|-----------------------------------------------------------|
| `OUTPUT_ROOT`   | `outputs`  | Directory to write results into                           |
| `LATEST_ONLY`   | `0`        | Set to `1` to fetch only the newest patch of each minor   |
| `PARALLEL_JOBS` | `4`        | Number of versions to fetch concurrently                  |

Already-fetched versions (non-empty output file present) are skipped, so
the script is safe to re-run. Versions that fail are recorded in
`<OUTPUT_ROOT>/failed-versions.log` and don't stop the rest of the run.

## Note

The `rhel-coreos` container image is around 2.5GB per version, so fetching
a range of ~10 versions can pull down roughly 20GB of disk space and
network payload. Plan accordingly when running the range script,
especially on constrained bandwidth or storage.
