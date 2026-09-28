#!/usr/bin/env bash

set -euo pipefail

readonly touchpad_devices=(
    "asue140d:00-04f3:31b9-mouse"
    "asue140d:00-04f3:31b9-touchpad"
)

for device in "${touchpad_devices[@]}"; do
    hyprctl eval "hl.device({ name = \"${device}\", enabled = false })" >/dev/null
done

sleep 1

for device in "${touchpad_devices[@]}"; do
    hyprctl eval "hl.device({ name = \"${device}\", enabled = true })" >/dev/null
done
