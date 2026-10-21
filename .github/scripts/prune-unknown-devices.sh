#!/bin/sh
# CI only: drop the devices the container's device definitions do not know
# yet from the manifest and the jungle, so that adding a device does not
# break CI until the image catches up. Local and store builds keep them.
set -e
devices=""
for d in "$HOME/.Garmin/ConnectIQ/Devices" /root/.Garmin/ConnectIQ/Devices; do
    if [ -d "$d" ]; then devices=$d; break; fi
done
[ -n "$devices" ] || { echo "no device definitions found" >&2; exit 1; }

for id in $(grep -o 'product id="[^"]*"' manifest.xml | cut -d'"' -f2); do
    if [ ! -d "$devices/$id" ]; then
        echo "::warning::device '$id' unknown to the CI image, not built"
        sed -i "/<iq:product id=\"$id\"\/>/d" manifest.xml
        sed -i "/^$id\./d" monkey.jungle
    fi
done
