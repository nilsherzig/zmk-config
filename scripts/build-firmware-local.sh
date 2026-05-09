#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
image_name="${IMAGE_NAME:-zmk-config-local-build}"
cache_volume="${CACHE_VOLUME:-zmk-config-build-cache}"
host_uid="$(id -u)"
host_gid="$(id -g)"

docker build -f "${repo_root}/Dockerfile.local" -t "${image_name}" "${repo_root}"
docker run --rm \
  --entrypoint sh \
  -v "${repo_root}/firmware:/workspaces/zmk-config/firmware" \
  -v "${cache_volume}:/workspaces/zmk-cache" \
  "${image_name}" \
  -c "mkdir -p /workspaces/zmk-cache/home /workspaces/zmk-config/firmware && chown -R ${host_uid}:${host_gid} /workspaces/zmk-cache /workspaces/zmk-config/firmware"

docker run --rm \
  --user "${host_uid}:${host_gid}" \
  -e GITHUB_WORKSPACE=/workspaces/zmk-config \
  -e CACHE_DIR=/workspaces/zmk-cache \
  -e HOME=/workspaces/zmk-cache/home \
  -v "${repo_root}:/workspaces/zmk-config" \
  -v "${cache_volume}:/workspaces/zmk-cache" \
  -w /workspaces/zmk-config \
  "${image_name}"
