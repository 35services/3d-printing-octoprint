#!/usr/bin/with-contenv bash
# Pin this instance to its own printer. The container sees all of the host's
# /dev (see docker-compose.yml), so without this OctoPrint's AUTO port would
# try every ttyACM* and could grab the other instance's printer. Only ports
# matching PRINTER_PORT_GLOB (a /dev/serial/by-id/ pattern, which matches the
# model, not one printer's serial number) are offered; the raw ttyACM*/ttyUSB*
# names are hidden.
set -e
[[ -n "${PRINTER_PORT_GLOB:-}" ]] || exit 0
basedir=/octoprint/octoprint
octoprint --basedir "$basedir" config set --json serial.additionalPorts "[\"$PRINTER_PORT_GLOB\"]" >/dev/null 2>&1
octoprint --basedir "$basedir" config set --json serial.blacklistedPorts '["/dev/ttyACM*", "/dev/ttyUSB*"]' >/dev/null 2>&1
# A remembered /dev/ttyACM0 would bypass the port list, so always autodetect.
octoprint --basedir "$basedir" config set serial.port AUTO >/dev/null 2>&1
octoprint --basedir "$basedir" config set --bool serial.autoconnect true >/dev/null 2>&1
