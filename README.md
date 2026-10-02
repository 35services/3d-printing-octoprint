# our octoprint setup

* https://plugins.octoprint.org/plugins/bgcode/
* https://plugins.octoprint.org/plugins/prusaslicerthumbnails/
* https://plugins.octoprint.org/plugins/cancelobject/
* https://plugins.octoprint.org/plugins/webcamextras/
* https://plugins.octoprint.org/plugins/tasmota/
* https://github.com/OctoPrint/OctoPrint-Slic3r (baked into the image with PrusaSlicer, see Dockerfile)

## Slicing profiles

`slic3r-profiles/` holds Prusa's official MK3 and MK4 (input shaper) PLA presets,
flattened for the PrusaSlicer 2.3 in the image. Both are baked into the image and
copied into each instance on start; `SLIC3R_DEFAULT_PROFILE` picks the default.
Regenerate with `slic3r-profiles/generate.sh`, then `docker compose build && docker compose up -d`.

![OctoPrint MK3 web UI](docs/screenshot.png)

## Webcam URLs

Each instance's classic webcam settings (OctoPrint → Settings → Webcam & Timelapse)
need two different kinds of URL:

| Setting | Value | Why |
|---|---|---|
| Stream URL | `/octoprint-mk3/webcam/?action=stream` (MK3), `/octoprint-mk4/webcam/?action=stream` (MK4) | Loaded by the browser, so it goes through the Caddy path of that printer. |
| Snapshot URL | `http://localhost:8080/?action=snapshot` (both) | Fetched by OctoPrint itself, inside the container (snapshots, timelapses). The `/octoprint-mk*/` prefix only exists in Caddy and gives a 404 inside the container; `:8080` is the container's own mjpg-streamer. |

These settings, like the API keys, live in the data volumes, not in this repo. After
moving a data volume to the other printer (see `docker-compose.yml`), check both
instances: the volume brings the old instance's URLs and API keys with it, so e.g.
PrusaSlicer's physical printer needs the new instance's API key (otherwise uploads
fail with "CSRF validation failed").

## Autologin (no password prompt from the landing page)

Both instances are set to automatically log visitors in as the existing `services`
admin account - no login screen, on `/octoprint-mk3/` and `/octoprint-mk4/` alike,
whether reached through Caddy or the bare `:91`/`:92` port. This relies on
OctoPrint's own [access control autologin](https://docs.octoprint.org/en/master/features/access_control.html#trusted-networks)
feature (`accessControl.autologinLocal`/`localNetworks`/`autologinAs` in
`config.yaml`), not a Caddy-side trick - so it's the same for every path in, there's
no way to make it Caddy-only (see "Why `172.18.0.1`" below).

**Security model:** this only narrows *who already has network access* down to
*also skipping the password*, it adds no new exposure. Both ports are already
published on `0.0.0.0` (reachable to the whole LAN directly, not just via Caddy/
Tailscale - see the `caddy` project's README), so this was already the trust
boundary before autologin existed. Decided together with the user 2026-10-02: ok
as long as that boundary (VPN or physically in the workshop) holds.

### Why `172.18.0.1`

Docker's port-publishing NAT means *every* inbound connection - direct to `:91`/
`:92`, or proxied by Caddy's `reverse_proxy localhost:91` - arrives at OctoPrint
from the `octoprint_default` bridge network's gateway IP, not the real client IP.
Confirmed empirically (not just inferred) via `docker inspect` and by diffing
`logs/auth.log`/`logs/tornado.log` before/after a request: always `172.18.0.1`,
for both instances, through both paths. That's the one address trusted below -
don't widen it to a `/24` or similar without first re-checking this (e.g. after
recreating the `octoprint_default` network, which can reassign the gateway IP).

### To replay (e.g. after a fresh data volume, or to redo this by hand)

The `services` user must already exist (it does, in both volumes' `users.yaml`) -
this grants no new credentials, only bypasses providing the existing ones per
request from a trusted address.

**The regular Settings API (`POST /api/settings`) silently drops `localNetworks`
and `autologinAs`** - confirmed by checking `config.yaml` on disk after a 200
response claimed success; only `autologinHeadsupAcknowledged` actually persisted
that way. Editing `config.yaml` directly is the only way found to set these two.
Do this with the container briefly stopped/restarted around the edit (not while
truly concurrently live-editing) to avoid racing OctoPrint's own writes to the
same file:

```bash
# Confirm the actual gateway IP first - don't assume it's still 172.18.0.1:
docker inspect <container-name> --format '{{(index .NetworkSettings.Networks "octoprint_default").Gateway}}'

docker compose exec <octoprint|octoprint-mk4> python3 -c "
import yaml
path = '/octoprint/octoprint/config.yaml'
with open(path) as f:
    cfg = yaml.safe_load(f) or {}
ac = cfg.setdefault('accessControl', {})
ac['autologinLocal'] = True
ac['localNetworks'] = ['172.18.0.1/32']  # the gateway IP confirmed above
ac['autologinAs'] = 'services'
ac['autologinHeadsupAcknowledged'] = True
with open(path, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)
"
docker compose restart <octoprint|octoprint-mk4>
```

Verify with a cookie-less request (no `-H "X-Api-Key"`, no session cookie - a
real fresh visit): `GET /` to pick up the session, then `GET /api/currentuser`
reusing that cookie should show `"name": "services"`, not `null`. `logs/
octoprint.log` should show `Logging in user services from 172.18.0.1 via
autologin`.
