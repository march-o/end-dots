#!/usr/bin/env bash

# Read only LAPTOP from the repo-local .env. An explicit environment value wins.
if [[ -z ${LAPTOP+x} && -f "$REPO_ROOT/.env" ]]; then
  while IFS= read -r machine_env_line || [[ -n "$machine_env_line" ]]; do
    [[ $machine_env_line == LAPTOP=* ]] || continue
    machine_laptop_value=${machine_env_line#LAPTOP=}
    case "$machine_laptop_value" in
      0|1) export LAPTOP="$machine_laptop_value" ;;
      *) printf 'Invalid LAPTOP value in %s/.env (expected 0 or 1).\n' "$REPO_ROOT" >&2; return 1 ;;
    esac
  done < "$REPO_ROOT/.env"
fi

case "${LAPTOP:-0}" in
  0|1) ;;
  *) printf 'LAPTOP must be 0 or 1.\n' >&2; return 1 ;;
esac
