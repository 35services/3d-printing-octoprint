#!/usr/bin/with-contenv bash
# Copy the baked-in Slic3r profiles into the data volume on every start (the
# repo is the source of truth, so edits made in the UI to these are overwritten)
# and optionally make one the default slicing profile.
set -e
basedir=/octoprint/octoprint
mkdir -p "$basedir/slicingProfiles/slic3r"
cp /opt/slic3r-profiles/*.profile "$basedir/slicingProfiles/slic3r/"

if [[ -n "${SLIC3R_DEFAULT_PROFILE:-}" ]]; then
  octoprint --basedir "$basedir" config set slicing.defaultSlicer slic3r >/dev/null 2>&1
  octoprint --basedir "$basedir" config set slicing.defaultProfiles.slic3r "$SLIC3R_DEFAULT_PROFILE" >/dev/null 2>&1
fi
