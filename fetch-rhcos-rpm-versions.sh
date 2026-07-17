#!/usr/bin/env bash
set -euo pipefail

: "${OCP_VERSION:?Usage: OCP_VERSION=4.22.5 $0}"
OUTPUT_FILE="${OUTPUT_FILE:-ocp-${OCP_VERSION}-rhcos-rpms.txt}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib-rhcos-rpm-versions.sh"

echo "==> Resolving rhel-coreos image for OCP ${OCP_VERSION}"

if ! fetch_rhcos_rpm_versions "${OCP_VERSION}" "${OUTPUT_FILE}"; then
    echo "ERROR: failed to fetch RPM versions for ${OCP_VERSION}" >&2
    exit 1
fi

echo "==> Saved package list to ${OUTPUT_FILE}"
