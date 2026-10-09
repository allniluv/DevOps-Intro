# Lab 10 — GitHub Codespaces (Option B)

## Setup

The QuickNotes application is configured through `.devcontainer/devcontainer.json`.

- Base image: `mcr.microsoft.com/devcontainers/go:1-1.24-bookworm`
- Forwarded port: `8080`
- Health endpoint: `/health`
- Notes endpoint: `/notes`
- Startup script: `.devcontainer/start-quicknotes.sh`
- Data file: `.codespace-data/notes.json`

The data directory is excluded from Git so runtime data is not committed.

## Warm latency

Five successful initial public `/health` requests:

| Request | Latency |
| --- | ---: |
| 1 | 0.190398 s |
| 2 | 0.129646 s |
| 3 | 0.059126 s |
| 4 | 0.171838 s |
| 5 | 0.119837 s |

Median p50: **0.129646 s**.

## Stop/start experiment

| Cycle | Response while stopped | Recovery after manual Start |
| --- | --- | ---: |
| 1 | HTTP 502, 0.916338 s | 1.312 s |
| 2 | HTTP 502, 5.968821 s | 1.165 s |
| 3 | HTTP 302, 0.784665 s | 0.859 s |

Recovery time was measured from the start of a polling script launched immediately after clicking Start until the first successful `/health` response. It is not an exact click-to-ready measurement.

A stopped Codespace did not automatically wake in response to a public request. Start it manually at https://github.com/codespaces.

## Persistence

Created note ID 5 before stopping the Codespace:

- Title: `Lab 10 Codespaces persistence test`
- Body: `Created before stopping and restarting the Codespace.`

After the stop/start cycle, the note remained in `.codespace-data/notes.json`, `/health` reported five notes, and the public `/notes` endpoint returned note ID 5.

This confirms persistence across the tested stop/start lifecycle only. It does not guarantee persistence after deleting or recreating the Codespace.

## Availability caveat

Later public checks were intermittent: four of five returned HTTP 200, one timed out, and other checks returned HTTP 502. The application also needed manual recovery on some starts. These observations are included rather than presented as guaranteed behavior.
