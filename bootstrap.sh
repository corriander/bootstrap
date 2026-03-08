#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./bootstrap.sh auth [extra ansible args...]
  ./bootstrap.sh [--dry-run] [--no-mr] [--preflight] [extra ansible args...]

Modes:
  auth        Generate the temporary bootstrap SSH key and temporary ~/.gitconfig.
  default     Run the main bootstrap playbook.

Options:
  --no-mr         Stop after Ansible bootstrap prep and do not run `mr update`.
  --preflight     Run only the preflight checks.
  --dry-run       Run Ansible in check mode.
  -h, --help      Show this help text.
EOF
}

run_auth() {
  cd "${ROOT_DIR}"
  local pubkey="${HOME}/.ssh/id_bootstrap.pub"
  local key_path="${HOME}/.ssh/id_bootstrap"
  local key_existed=0
  if [[ -f "${key_path}" ]]; then
    key_existed=1
  fi

  ansible-playbook -i inventories/local.ini playbooks/bootstrap-auth.yml "$@"

  if [[ -f "${pubkey}" ]]; then
    local key_status="New bootstrap key generated."
    if [[ "${key_existed}" -eq 1 ]]; then
      key_status="Existing bootstrap key reused."
    fi
    cat <<EOF

Bootstrap auth is prepared.

Bootstrap key path:
  ${key_path}

Key status:
  ${key_status}

Add this temporary public key to GitHub with a short expiry:

$(<"${pubkey}")

After approving the key, continue with:
  ./bootstrap.sh

Then run:
  If bootstrap later stops on an mr issue, fix it and rerun:
    ./bootstrap.sh
EOF
  fi
}

run_main() {
  local run_mr=1
  local preflight_only=0
  local dry_run=0
  local use_become_prompt=0
  local -a passthrough=()

  while (($#)); do
    case "$1" in
      --no-mr)
        run_mr=0
        shift
        ;;
      --preflight)
        preflight_only=1
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --ask-become-pass)
        use_become_prompt=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        passthrough+=("$1")
        shift
        ;;
    esac
  done

  local -a cmd=(ansible-playbook -i inventories/local.ini playbooks/wsl-bootstrap.yml)

  if [[ "${dry_run}" -eq 1 ]]; then
    cmd+=(--check)
  fi
  cmd+=(-e bootstrap_run_mr_update=false)

  cd "${ROOT_DIR}"
  if [[ "${preflight_only}" -eq 1 ]]; then
    cmd+=(--tags preflight)
  else
    local sudo_version
    sudo_version="$(sudo --version 2>&1 | head -n1 || true)"
    if [[ "${use_become_prompt}" -eq 1 ]]; then
      echo "Privilege mode: ansible become prompt (forced)." >&2
      cmd+=(--ask-become-pass)
    elif grep -qi 'sudo-rs' <<<"${sudo_version}"; then
      echo "Privilege mode: ansible become prompt (sudo-rs detected)." >&2
      cmd+=(--ask-become-pass)
    else
      echo "Privilege mode: sudo -v." >&2
      sudo -v
    fi
  fi

  "${cmd[@]}" "${passthrough[@]}"

  if [[ "${preflight_only}" -eq 1 || "${dry_run}" -eq 1 || "${run_mr}" -eq 0 ]]; then
    return 0
  fi

  echo "Running mr update..." >&2
  if GIT_CONFIG_GLOBAL="${HOME}/.gitconfig" mr update; then
    if [[ -f "${HOME}/.gitconfig" ]]; then
      rm -f "${HOME}/.gitconfig"
      echo "Removed temporary ${HOME}/.gitconfig." >&2
    fi
    return 0
  fi

  cat >&2 <<EOF

mr update did not complete cleanly.

Temporary bootstrap auth has been left in place:
  ${HOME}/.gitconfig
  ${HOME}/.ssh/id_bootstrap

Resolve the reported mr/vcsh issue, then rerun:
  ./bootstrap.sh
EOF
  return 1
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    auth)
      shift
      run_auth "$@"
      ;;
    -h|--help|help|"")
      if [[ -z "${cmd}" ]]; then
        run_main
      else
        usage
      fi
      ;;
    *)
      run_main "$@"
      ;;
  esac
}

main "$@"
