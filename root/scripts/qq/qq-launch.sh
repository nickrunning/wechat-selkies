#!/bin/bash

set -euo pipefail

default_flags=(
    --disable-renderer-backgrounding
    --disable-backgrounding-occluded-windows
    --disable-gpu
    --disable-gpu-compositing
    --disable-gpu-rasterization
    --disable-features=CalculateNativeWinOcclusion,UseSkiaRenderer
)

qq_flags_raw="${QQ_EXTRA_FLAGS:-}"
if [ -z "$qq_flags_raw" ]; then
    qq_flags_raw="${default_flags[*]}"
fi
read -r -a qq_flags <<<"$qq_flags_raw"

nice_level="${QQ_NICE_LEVEL:-0}"

if [[ "$nice_level" =~ ^-?[0-9]+$ ]]; then
    if [ "$nice_level" -ne 0 ]; then
        if nice -n "$nice_level" /usr/bin/qq --no-sandbox "${qq_flags[@]}"; then
            exit 0
        fi
        echo "[qq-launch] warning: failed to apply nice=$nice_level, fallback to default priority" >&2
    fi
fi

exec /usr/bin/qq --no-sandbox "${qq_flags[@]}"
