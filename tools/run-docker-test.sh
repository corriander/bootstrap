#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/.tmp/docker-test"

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

docker build -t bootstrap-ansible-test -f "${ROOT_DIR}/tools/Dockerfile.test" "${ROOT_DIR}"

docker run --rm \
  -v "${ROOT_DIR}:/workspace:ro" \
  -w /workspace \
  bootstrap-ansible-test \
  bash -lc '
    ansible-playbook -i inventories/local.ini playbooks/test-substrate.yml --become &&
    ansible-playbook -i inventories/local.ini playbooks/test-substrate.yml --become
  '
