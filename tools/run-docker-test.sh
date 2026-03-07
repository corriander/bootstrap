#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/.tmp/docker-test"
FIRST_RUN_LOG="${TMP_DIR}/first-run.log"
SECOND_RUN_LOG="${TMP_DIR}/second-run.log"

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

docker build -t bootstrap-ansible-test -f "${ROOT_DIR}/tools/Dockerfile.test" "${ROOT_DIR}"

docker run --rm \
  -v "${ROOT_DIR}:/workspace:ro" \
  -v "${TMP_DIR}:/tmp/bootstrap-test" \
  -w /workspace \
  bootstrap-ansible-test \
  bash -lc '
    set -euo pipefail
    ansible-playbook -i inventories/local.ini playbooks/test-substrate.yml --become | tee /tmp/bootstrap-test/first-run.log
    ansible-playbook -i inventories/local.ini playbooks/test-substrate.yml --become | tee /tmp/bootstrap-test/second-run.log
    grep -Eq "changed=0[[:space:]]" /tmp/bootstrap-test/second-run.log
  '
