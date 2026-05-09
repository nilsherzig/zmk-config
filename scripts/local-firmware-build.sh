#!/usr/bin/env bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-/workspaces/zmk-config}"
build_matrix_path="${BUILD_MATRIX_PATH:-build.yaml}"
config_path="${CONFIG_PATH:-config}"
fallback_binary="${FALLBACK_BINARY:-bin}"
output_dir="${OUTPUT_DIR:-firmware}"
cache_dir="${CACHE_DIR:-/workspaces/zmk-cache}"

matrix_file="${workspace}/${build_matrix_path}"
artifact_dir="${workspace}/${output_dir}"

if [ ! -f "${matrix_file}" ]; then
  printf 'error: build matrix not found: %s\n' "${matrix_file}" >&2
  exit 1
fi

if [ -e "${workspace}/zephyr/module.yml" ]; then
  base_dir="${cache_dir}/west-workspace"
  zmk_load_arg="-DZMK_EXTRA_MODULES=${workspace}"
  rm -rf "${base_dir:?}/${config_path}"
  mkdir -p "${base_dir}/${config_path}"
  cp -R "${workspace}/${config_path}/." "${base_dir}/${config_path}/"
else
  base_dir="${workspace}"
  zmk_load_arg=""
fi

mkdir -p "${artifact_dir}"

printf 'Preparing west workspace in %s\n' "${base_dir}"
pushd "${base_dir}" >/dev/null
west_manifest_hash="$(sha256sum "${config_path}/west.yml" | cut -d ' ' -f 1)"
west_manifest_hash_file="${cache_dir}/west-manifest.sha256"
if [ ! -d .west ]; then
  west init -l "${base_dir}/${config_path}"
  west_update_required=1
elif [ ! -f "${west_manifest_hash_file}" ] || [ "$(cat "${west_manifest_hash_file}")" != "${west_manifest_hash}" ]; then
  west_update_required=1
else
  west_update_required=0
fi

if [ "${west_update_required}" = 1 ]; then
  west update --fetch-opt=--filter=tree:0
  printf '%s\n' "${west_manifest_hash}" > "${west_manifest_hash_file}"
else
  printf 'West workspace is current; skipping west update\n'
fi
west zephyr-export
popd >/dev/null

build_count="$(yq '.include | length' "${matrix_file}")"

for index in $(seq 0 "$((build_count - 1))"); do
  board="$(yq -r ".include[${index}].board // \"\"" "${matrix_file}")"
  shield="$(yq -r ".include[${index}].shield // \"\"" "${matrix_file}")"
  snippet="$(yq -r ".include[${index}].snippet // \"\"" "${matrix_file}")"
  cmake_args="$(yq -r ".include[${index}].\"cmake-args\" // \"\"" "${matrix_file}")"
  artifact_name="$(yq -r ".include[${index}].\"artifact-name\" // \"\"" "${matrix_file}")"

  if [ -z "${board}" ]; then
    printf 'error: build.yaml entry %s has no board\n' "${index}" >&2
    exit 1
  fi

  if [ -z "${artifact_name}" ]; then
    artifact_name="${shield:+${shield}-}${board}-zmk"
  fi

  build_id="$(printf '%s' "${artifact_name}" | tr -c 'A-Za-z0-9_.-' '_')"
  build_dir="${cache_dir}/build/${build_id}"
  west_args=()
  cmake_arg_list=("-DZMK_CONFIG=${base_dir}/${config_path}")

  if [ -n "${snippet}" ]; then
    west_args+=("-S" "${snippet}")
  fi

  if [ -n "${shield}" ]; then
    cmake_arg_list+=("-DSHIELD=${shield}")
  fi

  if [ -n "${zmk_load_arg}" ]; then
    cmake_arg_list+=("${zmk_load_arg}")
  fi

  if [ -n "${cmake_args}" ]; then
    read -r -a extra_cmake_args <<< "${cmake_args}"
    cmake_arg_list+=("${extra_cmake_args[@]}")
  fi

  printf 'Building %s%s -> %s\n' "${shield:+${shield} - }" "${board}" "${artifact_name}"
  pushd "${base_dir}" >/dev/null
  west build -s zmk/app -d "${build_dir}" -b "${board}" "${west_args[@]}" -- "${cmake_arg_list[@]}"
  popd >/dev/null

  mkdir -p "${build_dir}/artifacts"
  if [ -f "${build_dir}/zephyr/zmk.uf2" ]; then
    cp "${build_dir}/zephyr/zmk.uf2" "${artifact_dir}/${artifact_name}.uf2"
  elif [ -f "${build_dir}/zephyr/zmk.${fallback_binary}" ]; then
    cp "${build_dir}/zephyr/zmk.${fallback_binary}" "${artifact_dir}/${artifact_name}.${fallback_binary}"
  else
    printf 'error: no zmk.uf2 or zmk.%s produced for %s\n' "${fallback_binary}" "${artifact_name}" >&2
    exit 1
  fi
done

printf 'Firmware files are in %s\n' "${artifact_dir}"
