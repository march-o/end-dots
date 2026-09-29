#!/usr/bin/env bash

case "${LAPTOP:-0}" in
  0) device_profile=desktop ;;
  1) device_profile=laptop ;;
  *) printf 'LAPTOP must be 0 or 1.\n' >&2; return 1 ;;
esac

source "$repo_root/sdata/dist-arch/config/devices/$device_profile.env"
