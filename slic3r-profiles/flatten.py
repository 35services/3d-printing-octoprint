"""Flatten a PrusaResearch vendor bundle preset (printer + print + filament) into one
config ini that PrusaSlicer 2.3 (the version in our image) accepts via --load.

Usage: flatten.py BUNDLE.ini KEYS23.ini OUT.ini PRINTER PRINT FILAMENT
KEYS23.ini is the full option list of 2.3 (see generate.sh)."""
import re, sys
bundle, defaults, out, printer, printp, filament = sys.argv[1:7]

def parse(path):
    secs, cur = {}, None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            cur = m.group(1); secs[cur] = {}
        elif cur and "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1); secs[cur][k.strip()] = v.strip()
    return secs

secs = parse(bundle)
def resolve(kind, name):
    own = secs[f"{kind}:{name}"]
    res = {}
    for parent in filter(None, (p.strip() for p in own.get("inherits", "").split(";"))):
        res.update(resolve(kind, parent))
    res.update(own)
    return res

known = {}
for line in open(defaults, encoding="utf-8"):
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1); known[k.strip()] = v.strip()

cfg = dict(known)
dropped = set()
for kind, name in (("print", printp), ("filament", filament), ("printer", printer)):
    for k, v in resolve(kind, name).items():
        if k in known: cfg[k] = v
        else: dropped.add(k)
# Enum values added after 2.3, mapped to the closest value 2.3 understands.
FIX = {
    ("top_fill_pattern", "monotoniclines"): "monotonic",
    ("bottom_fill_pattern", "monotoniclines"): "monotonic",
    ("gcode_flavor", "marlin2"): "marlin",
}
for (k, old), new in FIX.items():
    if cfg.get(k) == old: cfg[k] = new
# Custom G-code placeholders added after 2.3: rewrite or drop them.
GCODE = [
    (r"M862\.1 P\[nozzle_diameter\][^\\]*; nozzle check", "M862.1 P[nozzle_diameter] ; nozzle check"),
    (r"M555 [^\\]*\\n", ""),  # print-area hint for probing; firmware probes the whole bed instead
    (r"M201 X\{interpolate_table[^\\]*\\n", ""),  # weight-based accel ramp; machine limits apply
    (r"\{if ! spiral_vase\}M74 W\[extruded_weight_total\]\{endif\}", ""),
    (r"\binitial_tool\b", "initial_extruder"),
    (r"\bfilament_extruder_id\b", "0"),
    (r"\bmax_layer_z\b", "layer_z"),
]
for k in [k for k in cfg if k.endswith("_gcode")]:
    for pat, rep in GCODE:
        cfg[k] = re.sub(pat, lambda m: rep, cfg[k])
cfg.update(print_settings_id=printp, filament_settings_id=f'"{filament}"', printer_settings_id=printer)
with open(out, "w") as f:
    f.write(f"# Name: {printer.replace('Original Prusa ', '')} - {printp} - {filament}\n")
    f.write(f"# Description: Flattened from PrusaResearch bundle {secs['vendor']['config_version']} for PrusaSlicer 2.3\n")
    for k in sorted(cfg): f.write(f"{k} = {cfg[k]}\n")
print(out, "dropped (unknown to 2.3):", len(dropped), file=sys.stderr)
print(" ".join(sorted(dropped)), file=sys.stderr)
