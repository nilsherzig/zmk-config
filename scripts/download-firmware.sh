#!/usr/bin/env bash
set -euo pipefail

artifact_name="firmware"
output_dir="${1:-firmware}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

if ! command -v gh >/dev/null 2>&1; then
  printf 'error: gh CLI is required\n' >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  printf 'error: unzip is required\n' >&2
  exit 1
fi

remote_url="$(git remote get-url origin 2>/dev/null || true)"
repo="${remote_url#git@github.com:}"
repo="${repo#https://github.com/}"
repo="${repo%.git}"

if [[ -z "${remote_url}" || "${repo}" == "${remote_url}" ]]; then
  printf 'error: could not determine GitHub repo from origin remote\n' >&2
  exit 1
fi

run_id="$(gh run list --repo "${repo}" --limit 1 --json databaseId --jq '.[0].databaseId')"
if [[ -z "${run_id}" || "${run_id}" == "null" ]]; then
  printf 'error: no GitHub Actions runs found\n' >&2
  exit 1
fi

mkdir -p "${output_dir}"

printf 'Downloading artifact %s from %s run %s...\n' "${artifact_name}" "${repo}" "${run_id}"
gh run download "${run_id}" --repo "${repo}" --name "${artifact_name}" --dir "${tmp_dir}"

zip_file="$(find "${tmp_dir}" -maxdepth 1 -type f -name '*.zip' -print -quit)"
if [[ -n "${zip_file}" ]]; then
  unzip -o "${zip_file}" -d "${output_dir}"
else
  cp -R "${tmp_dir}"/. "${output_dir}"/
fi

printf 'Firmware files are in %s\n' "${output_dir}"
