#!/usr/bin/env bash
# Shared library: fetch_rhcos_rpm_versions <version> <output_file>
#
# Resolves the rhel-coreos image pull spec for an OCP release version via
# `oc adm release info --image-for=rhel-coreos` and lists its installed RPMs
# with `rpm -qa` into output_file. Returns non-zero on any failure without
# leaving a partially-written output_file behind.
#
# Note: since OCP 4.12, RHCOS ships via "CoreOS layering" and the
# machine-os-content image (with its baked-in /pkglist.txt) no longer
# exists; the RHCOS content lives in the rhel-coreos image instead, and
# `rpm -qa` is the supported way to list its packages (see
# https://access.redhat.com/solutions/5787001 and OCPBUGS-14263).

fetch_rhcos_rpm_versions() {
    local version="$1"
    local output_file="$2"
    local authfile="${AUTHFILE:-$HOME/.config/containers/auth.json}"

    local pullspec
    pullspec=$(oc adm release info --image-for=rhel-coreos "${version}" 2>/dev/null) || true

    if [[ -z "${pullspec}" ]]; then
        echo "could not resolve rhel-coreos image for ${version}" >&2
        return 1
    fi

    echo "==> Listing RPMs for ${version} from ${pullspec}"

    mkdir -p "$(dirname "${output_file}")"

    if ! podman run --rm --authfile "${authfile}" --entrypoint /bin/rpm \
        "${pullspec}" -qa 2>/dev/null | sort > "${output_file}"; then
        rm -f "${output_file}"
        echo "podman rpm -qa failed for ${version} (${pullspec})" >&2
        return 1
    fi

    if [[ ! -s "${output_file}" ]]; then
        rm -f "${output_file}"
        echo "empty package list for ${version} (${pullspec})" >&2
        return 1
    fi
}
