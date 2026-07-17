#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib-rhcos-rpm-versions.sh"

MINORS=(22 21 20 19 18)
OUTPUT_ROOT="${OUTPUT_ROOT:-outputs}"
LATEST_ONLY="${LATEST_ONLY:-0}"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
MIRROR_INDEX_URL="${MIRROR_INDEX_URL:-https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/}"

mkdir -p "${OUTPUT_ROOT}"
FAIL_LOG="${OUTPUT_ROOT}/failed-versions.log"

echo "==> Fetching version index from ${MIRROR_INDEX_URL}"
INDEX_HTML=$(curl -sf "${MIRROR_INDEX_URL}")

ALL_VERSIONS=()
for minor in "${MINORS[@]}"; do
    mapfile -t minor_versions < <(
        grep -oE "href=\"4\.${minor}\.[0-9]+/\"" <<< "${INDEX_HTML}" \
            | sed -E 's/href="(.*)\/"/\1/' \
            | sort -rV
    )

    if [[ "${#minor_versions[@]}" -eq 0 ]]; then
        echo "WARNING: no versions found for 4.${minor}" >&2
        continue
    fi

    if [[ "${LATEST_ONLY}" == "1" ]]; then
        minor_versions=("${minor_versions[0]}")
    fi

    ALL_VERSIONS+=("${minor_versions[@]}")
done

total="${#ALL_VERSIONS[@]}"
echo "==> ${total} version(s) to process (LATEST_ONLY=${LATEST_ONLY}, PARALLEL_JOBS=${PARALLEL_JOBS}, OUTPUT_ROOT=${OUTPUT_ROOT})"

process_version() {
    local version="$1"
    local minor="${version%.*}"
    local output_file="${OUTPUT_ROOT}/${minor}/ocp-${version}-rhcos-rpms.txt"

    if [[ -s "${output_file}" ]]; then
        echo "SKIP ${version} (already fetched: ${output_file})"
        return 0
    fi

    echo "FETCH ${version}"
    if fetch_rhcos_rpm_versions "${version}" "${output_file}"; then
        echo "OK ${version} -> ${output_file}"
    else
        echo "FAIL ${version}"
    fi
}
export -f fetch_rhcos_rpm_versions process_version
export OUTPUT_ROOT AUTHFILE

RESULTS_FILE="$(mktemp)"
trap 'rm -f "${RESULTS_FILE}"' EXIT

printf '%s\n' "${ALL_VERSIONS[@]}" \
    | xargs -P "${PARALLEL_JOBS}" -I{} bash -c 'set -euo pipefail; process_version "$@"' _ {} \
    | tee "${RESULTS_FILE}"

succeeded=$(grep -c '^OK ' "${RESULTS_FILE}" || true)
skipped=$(grep -c '^SKIP ' "${RESULTS_FILE}" || true)
failed=$(grep -c '^FAIL ' "${RESULTS_FILE}" || true)
grep '^FAIL ' "${RESULTS_FILE}" | awk '{print $2}' > "${FAIL_LOG}" || true

echo "==> Done. succeeded=${succeeded} skipped=${skipped} failed=${failed}"
if [[ "${failed}" -gt 0 ]]; then
    echo "==> Failed versions recorded in ${FAIL_LOG}"
fi
