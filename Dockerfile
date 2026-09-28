# OctoPrint + PrusaSlicer CLI for the OctoPrint-Slic3r plugin.
# The base image is Debian bullseye; its prusa-slicer (2.3.0) has arm64 builds,
# unlike Prusa's upstream AppImages, and 2.3 is the version the plugin's
# progress parsing targets.
FROM octoprint/octoprint:latest

# bullseye-security is being retired from the mirrors (LTS ended 2026-08) and its
# index points at packages no longer in the pool, so install from main only.
RUN sed -i '/bullseye-security/d' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends prusa-slicer \
 && rm -rf /var/lib/apt/lists/*

# The base image sets PIP_USER/PYTHONUSERBASE=/octoprint/plugins, which the data
# volume hides at runtime, so install into the system site-packages instead.
RUN PIP_USER=false pip install --no-cache-dir \
    https://github.com/OctoPrint/OctoPrint-Slic3r/archive/master.zip

# Prusa MK3/MK4 PLA profiles (see slic3r-profiles/), converted with the plugin's
# own parser. They live outside /octoprint because the data volume hides that
# path; the init script copies them in on every start.
COPY slic3r-profiles/prusa-mk3.ini slic3r-profiles/prusa-mk4.ini slic3r-profiles/convert.py /tmp/slic3r-profiles/
RUN mkdir -p /opt/slic3r-profiles \
 && python3 /tmp/slic3r-profiles/convert.py /tmp/slic3r-profiles /opt/slic3r-profiles \
 && rm -rf /tmp/slic3r-profiles
COPY --chmod=755 slic3r-profiles/cont-init.sh /etc/cont-init.d/10-slic3r-profiles

# Pins each instance to its printer model (PRINTER_PORT_GLOB), see the script.
COPY --chmod=755 printer-port.sh /etc/cont-init.d/20-printer-port
