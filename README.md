# bootstrap

Idempotent host bootstrap for personal Unix-like environments.

This repository covers two layers only:

1. `substrate`
   Install and configure the minimum OS-level requirements needed to bootstrap
   the user environment safely on a fresh or partially-prepared host.
2. `bootstrap`
   Hand off to the existing `mr` + `vcsh` dotfiles bootstrap by cloning the
   `bootstrap` repository and running `mr update`.

It does not attempt to restore the whole machine or replace backups. The
normal flow is:

1. Prepare a clean host.
2. Run this repository's Ansible playbook.
3. Optionally restore curated data from Borg/Vorta afterwards.

## Current Scope

The first supported target is WSL2 Ubuntu 25.10.

The playbook is intentionally conservative:

- safe to re-run on a host that already has some packages installed
- does not manage private keys
- keeps the existing `mr`/`vcsh` model intact

## Repo Layout

- `playbooks/wsl-bootstrap.yml`
  - entrypoint for WSL substrate + bootstrap handoff
- `inventories/`
  - local inventory definitions
- `roles/wsl_bootstrap/`
  - package installation, directory creation, clone/update tasks
- `group_vars/`
  - tunable defaults such as bootstrap repo URL and package set

## Prerequisites

The playbook assumes:

- Ubuntu 25.10 under WSL2
- `sudo` access
- `python3` available
- this repository has already been checked out locally

## First-Mile Bootstrap

The first checkout is deliberately a manual step. Install the minimal tools,
then clone this repository:

```bash
sudo apt update
sudo apt install -y ansible git
git clone https://github.com/corriander/bootstrap.git ~/repos/bootstrap
```

## Usage

Prepare temporary bootstrap auth:

```bash
cd ~/repos/bootstrap
./bootstrap.sh auth
```

That playbook generates `~/.ssh/id_bootstrap`, writes a temporary
bootstrap SSH key, prints the public key, and stops. Add the displayed key to
GitHub with a short expiry, then continue.

Run the main bootstrap locally against the current machine:

```bash
cd ~/repos/bootstrap
./bootstrap.sh
```

If `mr update` stops on a repo collision or checkout issue, fix it and rerun:

```bash
./bootstrap.sh
```

The temporary bootstrap `~/.gitconfig` is kept in place while `mr update` is
incomplete and removed automatically after a successful run.

Run only the preflight checks:

```bash
./bootstrap.sh --preflight
```

Run the main bootstrap but stop before `mr update`:

```bash
./bootstrap.sh --no-mr
```

Remove leftover temporary bootstrap state:

```bash
./bootstrap.sh clean
```

Also remove the temporary bootstrap SSH key pair:

```bash
./bootstrap.sh clean --all
```

Retire bootstrap tooling from a host that will not need it again:

```bash
./bootstrap.sh retire
```

Also remove the `ansible` package during retire:

```bash
./bootstrap.sh retire --rm-ansible
```

## What This Playbook Does

The WSL bootstrap role currently:

1. Runs preflight checks for platform, privilege escalation, and remote host resolution.
2. Uses the temporary bootstrap key via the temporary `~/.gitconfig` if present.
3. Updates `apt` metadata.
4. Installs the base packages required for `mr`/`vcsh` bootstrap.
5. Installs Oh My Zsh by default.
6. Ensures the expected local directory layout exists.
7. Seeds GitHub SSH host trust for bootstrap clones.
8. Checks whether the `bootstrap` vcsh repo is already present.
9. Clones the `bootstrap` repo via `vcsh` if missing.
10. Runs plain `mr update` after bootstrap prep unless `--no-mr` is used.

Default bootstrap installs currently include Oh My Zsh in addition to the apt
package substrate.

## Dotfiles Bootstrap Remote

The handoff into the private dotfiles bootstrap uses a temporary SSH key plus a
temporary `~/.gitconfig` shim. This avoids touching the steady-state Git config
that will later arrive via the `env` vcsh repository.

By default, the wrapper runs `mr update` as a plain shell command after Ansible
bootstrap prep. This keeps `mr` output transparent while still preserving a
two-command bootstrap flow. If `mr` fails, fix the reported issue and rerun
`./bootstrap.sh`.

The temporary `~/.gitconfig` is created only for the main bootstrap run. It is
removed automatically after a successful run, and also removed automatically
when `--no-mr` is used. If you need to clear bootstrap leftovers manually, use
`./bootstrap.sh clean`.

`./bootstrap.sh retire` is the stronger one-shot teardown. It removes the
temporary bootstrap auth state and deletes the local `~/repos/bootstrap`
checkout, but leaves `ansible` and any already-bootstrapped dotfiles/repos in
place.

Use `./bootstrap.sh retire --rm-ansible` if you also want to remove the
`ansible` package from the host via `apt`.

## Testing

Docker is reasonable for fast iteration on the substrate layer, but it will not
perfectly model WSL behaviour. It is still useful for validating:

- playbook syntax
- apt/package tasks
- directory creation
- idempotence of non-SSH tasks

Run the Docker substrate test with:

```bash
./tools/run-docker-test.sh
```

That script runs the substrate play twice in the same Ubuntu 25.10 container
and fails unless the second pass reports `changed=0`.

Clone/update behaviour against private remotes is better validated in the real
WSL target once the base tasks are known-good.
