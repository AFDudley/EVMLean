#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s <version>\n' "$0" >&2
  printf 'examples: %s 20.0.2 | %s v20.0.2 | %s tests@v20.0.2\n' "$0" "$0" "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

version="${1#tests@}"
version="${version#v}"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  usage
  exit 2
fi

release="tests@v${version}"
asset_url="https://github.com/ethereum/execution-specs/releases/download/tests%40v${version}/fixtures.tar.gz"
cache_root="${EEST_CACHE_DIR:-.cache/eest}"
target="${cache_root}/tests-v${version}"
archive="${cache_root}/fixtures-tests-v${version}.tar.gz"

known_sha256=''
case "${version}" in
  20.0.2)
    known_sha256='1280540950a4c3470a421416b6f35458a9b635827265c29e5aef1ae839ae1788'
    ;;
esac
expected_sha256="${EEST_SHA256:-${known_sha256}}"
if [[ -z "${expected_sha256}" ]]; then
  printf 'no pinned checksum is known for %s\n' "${release}" >&2
  printf 'set EEST_SHA256 to the release artifact SHA-256 and retry\n' >&2
  exit 2
fi

mkdir -p "${cache_root}"
if [[ ! -f "${archive}" ]]; then
  temporary="${archive}.partial"
  curl --fail --location --retry 3 --output "${temporary}" "${asset_url}"
  mv "${temporary}" "${archive}"
fi

actual_sha256="$(sha256sum "${archive}" | cut -d ' ' -f 1)"
if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
  printf 'checksum mismatch for %s\nexpected: %s\nactual:   %s\n' \
    "${archive}" "${expected_sha256}" "${actual_sha256}" >&2
  exit 1
fi

if [[ ! -f "${target}/.complete" ]]; then
  if [[ -e "${target}" ]]; then
    printf 'incomplete target exists; move it aside and retry: %s\n' "${target}" >&2
    exit 1
  fi
  temporary_dir="$(mktemp -d "${cache_root}/extract-tests-v${version}.XXXXXX")"
  tar -xzf "${archive}" -C "${temporary_dir}"
  printf '%s\n' "${release}" > "${temporary_dir}/.complete"
  mv "${temporary_dir}" "${target}"
fi

printf '%s\n' "${target}"
