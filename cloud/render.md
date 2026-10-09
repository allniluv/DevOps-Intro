# QuickNotes on Render

## Deployment

* Platform: Render Free Web Service
* Image: `ghcr.io/allniluv/devops-intro/quicknotes:v0.1.1`
* Architecture: `linux/amd64`
* Public URL: https://quicknotes-v0-1-0-0bjb.onrender.com
* Health endpoint: `/health`

Environment variables:

```text
PORT=10000
ADDR=:10000
```

The initial configuration used `ADDR=10000` and failed with `listen tcp: address 10000: missing port in address`. Changing it to `ADDR=:10000` fixed the issue, and the service became Live.

## Release workflow

The GitHub Actions workflow in `.github/workflows/release.yml` runs when a tag matching `v*` is pushed. It builds the image for `linux/amd64`, pushes the versioned tag and `latest` to GHCR, and triggers a Render deployment using a deploy hook.

The workflow uses `GITHUB_TOKEN` and the minimum required permissions: `contents: read` and `packages: write`. The Render deploy-hook URL is stored in the GitHub Actions secret `RENDER_DEPLOY_HOOK_URL`.

The `v0.1.1` release workflow completed successfully, including the Render deploy-hook step.

## Public verification

The public `/health` endpoint returned HTTP 200:

```json
{"notes":4,"status":"ok"}
```

The `/notes` endpoint returned four seeded notes.

## Warm request latency

Measurements were taken against `/health`.

| Request          |                 Duration |
| ---------------- | -----------------------: |
| 1                |               0.550743 s |
| 2                |               0.622880 s |
| 3                |               0.752222 s |
| 4                |               0.694727 s |
| 5                |               0.760540 s |
| **Median (p50)** | **0.694727 s (~695 ms)** |

## Cold-start latency

The service was idle for at least 20 minutes before each request.

| Sample   | Timestamp (MSK)     | HTTP |                   Duration |
| -------- | ------------------- | ---: | -------------------------: |
| 1        | 2026-10-08 23:30:27 |  200 |                14.150038 s |
| 2        | 2026-10-09 07:38:25 |  200 |                33.295836 s |
| 3        | 2026-10-09 08:00:06 |  200 |                13.941436 s |
| **Mean** |                     |      | **20.462437 s (~20.46 s)** |

Cold requests were substantially slower than warm requests. These are three observed samples, not a statistically rigorous benchmark.

## Persistence test

A note titled `Lab 10 persistence test` was created successfully. The API returned HTTP 201 with ID `5`, and an immediate `GET /notes` showed the note.

After a subsequent Render deployment, `/health` reported four notes and note ID `5` was absent. The note was also absent during all three later cold-start checks; only the four seeded notes were returned.

**Result:** durable persistence was not demonstrated across the observed deployment/lifecycle. A persistent disk or external database would be needed for reliable storage of user-created notes.

## Notes

* Dockerfile `EXPOSE` documents the intended container port; it does not make the application listen on that port by itself.
* Render provides `PORT` to the web service. The application must listen on a valid address such as `:10000`.
* This deployment uses the existing GHCR image. Building directly from a connected repository on Render is an alternative, but would move image building into Render's build pipeline.


