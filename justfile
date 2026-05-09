set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Firmware lokal per Docker bauen.
firmware-lokal-bauen:
  ./scripts/build-firmware-local.sh

# Firmware vom letzten GitHub-Actions-Run fetchen.
firmware-von-letzten-github-run-fetchen:
  ./scripts/download-firmware.sh
