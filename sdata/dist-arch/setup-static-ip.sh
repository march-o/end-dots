#!/usr/bin/env bash
set -euo pipefail

connection="Wired connection 1"
address="192.168.8.33/24"
gateway="192.168.8.1"
dns="192.168.8.1"

case "${1:-apply}" in
  apply)
    sudo nmcli connection modify "$connection" \
      ipv4.method manual \
      ipv4.addresses "$address" \
      ipv4.gateway "$gateway" \
      ipv4.dns "$dns" \
      ipv4.ignore-auto-dns yes
    sudo nmcli connection up "$connection"
    ;;
  dhcp|rollback)
    sudo nmcli connection modify "$connection" \
      ipv4.method auto \
      ipv4.addresses "" \
      ipv4.gateway "" \
      ipv4.dns "" \
      ipv4.ignore-auto-dns no
    sudo nmcli connection up "$connection"
    ;;
  *)
    echo "Usage: $0 [apply|dhcp]" >&2
    exit 2
    ;;
esac

