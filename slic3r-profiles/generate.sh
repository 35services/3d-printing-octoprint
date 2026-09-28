#!/bin/sh
# Regenerate the OctoPrint-Slic3r profiles from Prusa's official vendor bundle.
# Needs the octoprint-prusaslicer image (docker compose build) for the 2.3 option list.
set -eu
cd "$(dirname "$0")"
BUNDLE=${BUNDLE:-2.5.10}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

curl -sfL -o "$tmp/PrusaResearch.ini" \
  "https://raw.githubusercontent.com/prusa3d/PrusaSlicer-settings-prusa-fff/main/PrusaResearch/$BUNDLE.ini"

# 2.3's --save only writes changed options, but every sliced G-code ends with the
# full config, so slice a cube with defaults and keep that trailer.
cat > "$tmp/cube.py" <<'PY'
import struct
v = [(0,0,0),(20,0,0),(20,20,0),(0,20,0),(0,0,20),(20,0,20),(20,20,20),(0,20,20)]
f = [(0,2,1),(0,3,2),(4,5,6),(4,6,7),(0,1,5),(0,5,4),(1,2,6),(1,6,5),(2,3,7),(2,7,6),(3,0,4),(3,4,7)]
d = bytes(80) + struct.pack("<I", len(f))
for t in f:
    d += struct.pack("<3f", 0, 0, 0) + b"".join(struct.pack("<3f", *v[i]) for i in t) + bytes(2)
open("/w/cube.stl", "wb").write(d)
PY
docker run --rm -v "$tmp:/w" --entrypoint sh octoprint-prusaslicer:latest -c \
  'python3 /w/cube.py && prusa-slicer -g -o /w/cube.gcode /w/cube.stl >/dev/null 2>&1'
sed -n '/^; avoid_crossing_perimeters = /,$s/^; //p' "$tmp/cube.gcode" > "$tmp/keys23.ini"

python3 flatten.py "$tmp/PrusaResearch.ini" "$tmp/keys23.ini" prusa-mk3.ini \
  "Original Prusa i3 MK3" "0.15mm QUALITY @MK3" "Prusament PLA"
python3 flatten.py "$tmp/PrusaResearch.ini" "$tmp/keys23.ini" prusa-mk4.ini \
  "Original Prusa MK4 Input Shaper 0.4 nozzle" "0.20mm SPEED @MK4IS 0.4" "Prusament PLA @PGIS"
