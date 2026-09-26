#!/usr/bin/env bash

# Read only LAPTOP from the repo-local .env. An explicit environment value wins.
if [[ ${MACHINE_ENV_REQUIRED:-0} == 1 && ! -f "$REPO_ROOT/.env" ]]; then
  printf 'Missing %s/.env. Copy .env.example to .env and set LAPTOP=0 or LAPTOP=1.\n' "$REPO_ROOT" >&2
  return 1
fi

machine_laptop_found=0
if [[ -f "$REPO_ROOT/.env" ]]; then
  while IFS= read -r machine_env_line || [[ -n "$machine_env_line" ]]; do
    [[ $machine_env_line == LAPTOP=* ]] || continue
    machine_laptop_found=1
    machine_laptop_value=${machine_env_line#LAPTOP=}
    case "$machine_laptop_value" in
      0|1) if [[ -z ${LAPTOP+x} ]]; then export LAPTOP="$machine_laptop_value"; fi ;;
      *) printf 'Invalid LAPTOP value in %s/.env (expected 0 or 1).\n' "$REPO_ROOT" >&2; return 1 ;;
    esac
  done < "$REPO_ROOT/.env"
fi

if [[ ${MACHINE_ENV_REQUIRED:-0} == 1 && $machine_laptop_found == 0 ]]; then
  printf 'Missing LAPTOP in %s/.env (expected LAPTOP=0 or LAPTOP=1).\n' "$REPO_ROOT" >&2
  return 1
fi

case "${LAPTOP:-0}" in
  0|1) ;;
  *) printf 'LAPTOP must be 0 or 1.\n' >&2; return 1 ;;
esac
