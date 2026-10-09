# Lab 10 — CI/CD, Cloud Deployment, and Release Engineering

## Goal

Automate QuickNotes releases with GitHub Actions, publish versioned container images to GitHub Container Registry (GHCR), and evaluate manual stop/start behavior using GitHub Codespaces.

## Task 1 — Release automation

Implemented `.github/workflows/release.yml`.

The workflow:
- Triggers on version tags matching `v*`.
- Builds the QuickNotes container image for `linux/amd64`.
- Publishes versioned and `latest` tags to GHCR.
- Uses `GITHUB_TOKEN` with `packages: write` and read-only repository contents permission.
- Pins third-party GitHub Actions to full commit SHAs.

The release for `v0.1.1` completed successfully.

Published image:

`ghcr.io/allniluv/devops-intro/quicknotes:v0.1.1`

Successful GitHub Actions run:
https://github.com/allniluv/DevOps-Intro/actions/runs/37837208428

The Codespaces experiment is documented separately in `cloud/codespaces.md`. The release workflow publishes images; starting a Codespace is a manual operation.

## Task 2 — GitHub Codespaces (Option B)

The QuickNotes application was run in a GitHub Codespace using `.devcontainer/devcontainer.json`. Port `8080` was forwarded for access to `/health` and `/notes`.

The application returned HTTP 200 from `/health` when running. The response reported five notes after the persistence test.

### Warm latency measurements

Five initial successful requests to the public `/health` endpoint:

| Request | Latency |
| --- | ---: |
| 1 | 0.190398 s |
| 2 | 0.129646 s |
| 3 | 0.059126 s |
| 4 | 0.171838 s |
| 5 | 0.119837 s |

The median (p50) was **0.129646 seconds**.

### Manual stop/start experiment

A request to the public URL does not automatically start a stopped Codespace. The observed responses while stopped were:

| Cycle | HTTP status | Response time |
| --- | ---: | ---: |
| 1 | 502 | 0.916338 s |
| 2 | 502 | 5.968821 s |
| 3 | 302 | 0.784665 s |

After manually starting the Codespace, time from the beginning of the polling script until the first successful health response was measured:

| Cycle | Observed recovery |
| --- | ---: |
| 1 | 1.312 s |
| 2 | 1.165 s |
| 3 | 0.859 s |

These recovery measurements begin when the polling script starts after clicking Start. They are not exact measurements from the click itself. A stopped Codespace requires manual start; requests do not wake it automatically.

The public tunnel was intermittently unstable during later checks, including HTTP 502 responses and one timeout in a set of five checks. Four of those five checks returned HTTP 200. The results therefore demonstrate the observed behavior in this experiment, not a guarantee of public endpoint availability.

### Persistence test

Before stopping the Codespace, a note was created through the API:

- ID: `5`
- Title: `Lab 10 Codespaces persistence test`
- Body: `Created before stopping and restarting the Codespace.`

After stopping and starting the Codespace, the note was found in `.codespace-data/notes.json`. The application log reported that five notes were loaded, and the note was subsequently retrieved through the public `/notes` endpoint.

**Result:** the test note survived the stop/start lifecycle tested. This demonstrates persistence for this Codespace experiment, but does not establish that data would survive deletion or recreation of the Codespace.

## Design questions

### a. OIDC vs. GITHUB_TOKEN

For publishing to GHCR from the same repository, `GITHUB_TOKEN` with `packages: write` is sufficient. OIDC is useful for obtaining short-lived credentials from external cloud providers without storing long-lived secrets.

### b. `latest` vs. immutable version tags

A version tag such as `v0.1.1` identifies a specific release and supports reproducible deployments and rollbacks. `latest` is convenient for users who want the newest published image without specifying a version. Publishing both provides convenience and version-specific references.

### c. Least-privilege permissions

A workflow should receive only the permissions it needs. `packages: write` allows the release workflow to publish container images without granting unnecessary write access to repository contents.

### d. Why use a container registry?

A container registry stores versioned images so deployment environments can retrieve a built artifact. This separates building from running and makes releases easier to reproduce and roll back.

### e. Why publish an existing image?

Building and publishing an image in CI creates a release artifact that can be referenced by version. A deployment environment can run that artifact rather than independently rebuilding the application source.

### f. What are the limitations of this deployment approach?

A stopped Codespace does not automatically start when its public URL is requested. Manual startup introduces an availability gap. In this experiment, the forwarded public tunnel also returned intermittent 502 responses and a timeout. The application data file survived the tested stop/start cycle, but Codespaces storage should not be treated as a substitute for a dedicated durable production database.

## Conclusion

The release workflow successfully published the QuickNotes image to GHCR. The Codespaces experiment recorded warm latency, three manual stop/start recovery measurements, stopped-state responses, and a successful persistence check for the test note. The experiment also revealed limitations: manual startup is required and the public forwarded endpoint was intermittently unavailable. These results describe the tested setup and should not be interpreted as a production availability guarantee.
