"""Convert the flattened inis into OctoPrint-Slic3r .profile files (build time)."""
import sys
from octoprint_slic3r.profile import Profile

src, dst = sys.argv[1:3]
for m in ("mk3", "mk4"):
    d, name, desc = Profile.from_slic3r_ini(f"{src}/prusa-{m}.ini")
    Profile.to_slic3r_ini(d, f"{dst}/prusa_{m}_pla.profile", name.strip(), desc.strip())
