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
