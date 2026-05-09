set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

firmware-build-local:
  ./scripts/build-firmware-local.sh

firmware-fetch-from-last-github-run:
  ./scripts/download-firmware.sh
