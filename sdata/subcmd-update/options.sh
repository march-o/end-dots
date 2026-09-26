# Handle args for subcmd: update
# shellcheck shell=bash

showhelp(){
printf "Syntax: $0 update

Apply the current repository checkout to this Arch system.
Set LAPTOP=1 to also apply laptop-specific configuration.
"
}

case "${1:-}" in
  -h|--help) showhelp; exit ;;
  "") ;;
  *) echo "$0: update does not accept arguments." >&2; exit 2 ;;
esac
