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
authenticate to GitHub, then clone this repository:

```bash
sudo apt update
sudo apt install -y ansible git gh
gh auth login
gh repo clone corriander/bootstrap ~/repos/bootstrap
```

## Usage

Run locally against the current machine:

```bash
cd ~/repos/bootstrap
ansible-playbook -i inventories/local.ini playbooks/wsl-bootstrap.yml --ask-become-pass
```

## What This Playbook Does

The WSL bootstrap role currently:

1. Updates `apt` metadata.
2. Installs the base packages required for `mr`/`vcsh` bootstrap.
3. Ensures the expected local directory layout exists.
4. Checks whether the `bootstrap` vcsh repo is already present.
5. Clones the `bootstrap` repo via `vcsh` if missing.
6. Runs `mr update` once `.mrconfig` is available.

This deliberately avoids managing optional installables for now.

## Dotfiles Bootstrap Remote

This repository does not use `gh` after the initial clone. The handoff into the
private dotfiles bootstrap uses normal Git via `vcsh clone`, so repository
hosting can change later without redesigning the playbook.

## Testing

Docker is reasonable for fast iteration on the substrate layer, but it will not
perfectly model WSL behaviour. It is still useful for validating:

- playbook syntax
- apt/package tasks
- directory creation
- idempotence of non-SSH tasks

Clone/update behaviour against private remotes is better validated in the real
WSL target once the base tasks are known-good.
