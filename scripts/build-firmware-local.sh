#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
image_name="${IMAGE_NAME:-zmk-config-local-build}"
cache_volume="${CACHE_VOLUME:-zmk-config-build-cache}"

docker build -f "${repo_root}/Dockerfile.local" -t "${image_name}" "${repo_root}"
docker run --rm \
  -e GITHUB_WORKSPACE=/workspaces/zmk-config \
  -e CACHE_DIR=/workspaces/zmk-cache \
  -v "${repo_root}:/workspaces/zmk-config" \
  -v "${cache_volume}:/workspaces/zmk-cache" \
  -w /workspaces/zmk-config \
  "${image_name}"
