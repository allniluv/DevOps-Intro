# Lab 10 — CI/CD, Cloud Deployment, and Release Engineering

## Goal

Automate QuickNotes releases with GitHub Actions, publish a container image to GitHub Container Registry (GHCR), and deploy the application to a cloud hosting provider.

## Task 1 — Release automation

Implemented a GitHub Actions release workflow in `.github/workflows/release.yml`.

The workflow:

* Triggers on version tags matching `v*`.
* Builds the QuickNotes container image for `linux/amd64`.
* Publishes versioned and `latest` images to GHCR.
* Uses `GITHUB_TOKEN` with the required package permissions.
* Uses a GitHub Actions secret for the Render deploy hook.
* Pins third-party GitHub Actions to full commit SHAs.

The release workflow completed successfully for `v0.1.1`, including the Render deploy-hook step.

Published image:

`ghcr.io/allniluv/devops-intro/quicknotes:v0.1.1`

## Task 2 — Cloud deployment

QuickNotes was deployed to Render using the published GHCR image.

* Public URL: https://quicknotes-v0-1-0-0bjb.onrender.com
* Health endpoint: `/health`
* Container architecture: `linux/amd64`
* Container port configuration: `ADDR=:10000`
* Render port: `10000`

The health endpoint returned HTTP 200 with a JSON response indicating `"status":"ok"`. The `/notes` endpoint returned the seeded notes.

### Latency measurements

Warm requests:

| Request | Latency |
| ------- | ------: |
| 1       | 0.551 s |
| 2       | 0.623 s |
| 3       | 0.752 s |
| 4       | 0.695 s |
| 5       | 0.761 s |

The median warm latency (p50) for these five samples was approximately **0.695 seconds**.

Cold requests after an idle period:

| Request time (MSK) | HTTP status |  Latency |
| ------------------ | ----------: | -------: |
| Oct 8, 23:30       |         200 | 14.150 s |
| Oct 9, 07:38       |         200 | 33.296 s |
| Oct 9, 08:00       |         200 | 13.941 s |

The mean of these three cold-request measurements was approximately **20.462 seconds**. These results show that cold starts can be significantly slower than warm requests.

### Persistence test

A test note titled `Lab 10 persistence test` was created successfully with HTTP 201 and ID 5. It was initially visible through the API.

After a subsequent Render deployment, the health endpoint reported four notes and the test note was no longer present. It was also absent during later checks. Therefore, the observed test note was not durable across the deployment/lifecycle events tested.

## Design questions

### d. Why use a container registry?

A container registry stores versioned images so deployment environments can pull the same built artifact. This separates building from running and makes releases easier to reproduce and roll back.

### e. Why deploy an existing image instead of building on the hosting provider?

Deploying an image from GHCR lets CI build and publish the artifact once, while Render runs that exact image. This improves consistency between the release workflow and the deployed version.

### f. What are the limitations of the deployment?

The measurements show a substantial cold-start delay. The persistence test also showed that the test note did not survive a deployment/lifecycle event. A production deployment that requires durable user data should use an appropriate persistent storage service and should be tested for availability and recovery.

## Conclusion

The release workflow successfully built and published the QuickNotes image and triggered deployment to Render. The public health endpoint returned HTTP 200. Warm requests were faster than cold requests, and the persistence test identified a limitation that should be addressed before using the deployment for durable user data.

## Task 1 — Design questions

### a. OIDC vs GITHUB_TOKEN

For publishing to GHCR from the same repository, GITHUB_TOKEN with packages: write is sufficient. OIDC is useful for authenticating to external cloud providers without storing long-lived credentials. It provides short-lived, identity-based credentials that the provider can validate.

### b. latest vs immutable version tags

An immutable version tag such as v0.1.1 identifies a specific release and supports reproducible deployments and rollbacks. The latest tag is convenient when users want the newest release without specifying a version. Publishing both provides convenience while retaining version-specific deployment options.

### c. Least-privilege permissions

The principle of least privilege grants a workflow only the permissions it needs. packages: write permits publishing container images without unnecessary write access to repository contents or other resources. If a workflow step is compromised, narrow permissions reduce the potential damage compared with broad write access.

## Additional deployment configuration

- Hosting option: Render Free Web Service using the existing public GHCR image.
- Render environment variables: PORT=10000 and ADDR=:10000.
- Health check path: /health.
- The application returned HTTP 200 from /health during the recorded checks.
- The release workflow uses the RENDER_DEPLOY_HOOK_URL GitHub Actions secret; the secret value is not stored in this repository.

### Additional design details

Render free services spin down after inactivity, so waking a container adds startup and scheduling delay. Cloud Run is designed for managed serverless scaling and can have different startup and scaling characteristics; both platforms trade idle resource usage for cold-start latency.

Render supplies PORT to tell the application which port to listen on. EXPOSE in a Dockerfile is image metadata, not a command that configures the application listener. Setting PORT=10000 and ADDR=:10000 makes the configured ports agree and avoids a port-mismatch restart.

Using an existing GHCR image separates CI building from deployment and allows the same artifact to be scanned and deployed. Building from source on Render can be simpler initially, but may introduce differences in build caching and artifact reproducibility. The persistence test note disappeared after a deployment/lifecycle event, so the observed storage was not durable; persistent user data requires an appropriate durable storage service.


## CI release workflow evidence

Successful GitHub Actions run: https://github.com/allniluv/DevOps-Intro/actions/runs/37837208428
