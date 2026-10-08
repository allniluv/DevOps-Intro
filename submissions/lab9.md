# Lab 9 — Security Scanning and Hardening

## 1. Scope and tools

The QuickNotes application was checked using:

- Trivy 0.59.1 — image, filesystem and SBOM scanning
- Trivy 0.68.2 — configuration scanning because Trivy 0.59.1 reported a policy-bundle compatibility error
- OWASP ZAP 2.16.1 — passive baseline scan
- Go 1.27.1
- govulncheck v1.8.0 — bonus CI/PR gate

The final application image is `quicknotes:lab9`.

## 2. Trivy image scan

The original `quicknotes:lab6` image contained 19 HIGH vulnerabilities and 0 CRITICAL vulnerabilities in Go runtime/library components.

All 19 findings were classified as FIX because upstream fixes were available.

The builder image in `app/Dockerfile` was updated from `golang:1.24-alpine` to `golang:1.27.1-alpine`.

The image was rebuilt as `quicknotes:lab9`.

Final result:

    Total: 0 (HIGH: 0, CRITICAL: 0)

Final image digest:

    sha256:78d3704f70bf325aeeb000d2d73da0c4bcbb5e8bb5685e7081bf9b7e40fbf881

Artifacts:

- `artifacts/lab9/trivy/image-final.json`
- `artifacts/lab9/trivy/image-final.txt`

## 3. Trivy filesystem scan

The initial filesystem scan identified:

    .vagrant/machines/default/virtualbox/private_key
    HIGH: AsymmetricPrivateKey

Disposition: ACCEPT / OUT OF SCOPE.

This is a real generated Vagrant private key, but it belongs to local `.vagrant` runtime state and is not part of the application source or shipped image.

The finding was not added to `.trivyignore`. `.vagrant` was excluded from the source filesystem scan because it is generated local VM state.

The final applicable source scan had no HIGH/CRITICAL findings.

Artifact:

`artifacts/lab9/trivy/fs-final.txt`

## 4. Trivy configuration scan

Trivy 0.59.1 reported a policy-bundle compatibility error:

    undefined ref: input.aws.ec2.requestedamis
    Failed to find embedded check

This was a scanner policy compatibility issue rather than a project finding.

The configuration scan was repeated with Trivy 0.68.2.

Final result:

    Target       Type        Misconfigurations
    Dockerfile   dockerfile  0

Artifact:

`artifacts/lab9/trivy/config-final.txt`

## 5. SBOM

A CycloneDX SBOM was generated for the final `quicknotes:lab9` image.

The SBOM contains:

- CycloneDX format
- specification version 1.6
- 12 components
- Go standard library 1.27.1
- Debian 13.7 base components

Artifact:

`artifacts/lab9/trivy/quicknotes-lab9-sbom-final.json`

An SBOM provides a machine-readable inventory of software components and versions. During incident response it can be used to quickly determine whether an affected component or version is present in an artifact.

## 6. OWASP ZAP baseline scan

ZAP 2.16.1 was run in baseline/passive mode against the running QuickNotes application.

Initial scan:

    FAIL-NEW: 0
    FAIL-INPROG: 0
    WARN-NEW: 2
    WARN-INPROG: 0
    INFO: 0
    IGNORE: 0
    PASS: 65

Findings:

### 10049 — Storable and Cacheable Content

Affected:

- `/`
- `/sitemap.xml`

### 10116 — ZAP is Out of Date

Disposition: WATCH / ACCEPT.

This is a scanner-version maintenance warning rather than an application vulnerability.

## 7. ZAP remediation

A global middleware was added in `app/handlers.go`:

    func securityHeaders(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            w.Header().Set("Cache-Control", "no-store")
            next.ServeHTTP(w, r)
        })
    }

The middleware is applied to the complete application handler tree in `app/main.go`.

This was necessary because middleware applied only to individual application handlers did not affect `http.ServeMux` generated 404 responses.

Tests were added to verify the cache policy on 404 responses.

After the fix:

- `/health` returns `Cache-Control: no-store`
- `/` returns 404 with `Cache-Control: no-store`
- `/sitemap.xml` returns 404 with `Cache-Control: no-store`

Final ZAP scan:

    FAIL-NEW: 0
    FAIL-INPROG: 0
    WARN-NEW: 2
    WARN-INPROG: 0
    INFO: 0
    IGNORE: 0
    PASS: 65

The 10049 alert changed from detecting potentially storable/cacheable content to detecting the explicitly non-storable response. This verifies that the response policy was changed to `Cache-Control: no-store`.

Final triage:

| Finding | Disposition | Reason |
|---|---|---|
| 10049 Non-Storable Content | FIX / VERIFIED | Explicit `Cache-Control: no-store` is returned globally |
| 10116 ZAP is Out of Date | WATCH / ACCEPT | Tool-version maintenance warning |

Artifacts:

- `artifacts/lab9/zap/zap-baseline.html`
- `artifacts/lab9/zap/zap-baseline.json`
- `artifacts/lab9/zap/zap-baseline-after.html`
- `artifacts/lab9/zap/zap-baseline-after.json`
- `artifacts/lab9/zap/zap.yaml`

## 8. Security hardening changes

1. Updated the Go builder image to Go 1.27.1.
2. Added global `Cache-Control: no-store` middleware.
3. Added tests covering security headers on normal and 404 responses.
4. Kept the existing distroless/non-root container design.

## 9. Design questions

### a) Why is severity alone insufficient for triage?

Severity is only one input. Reachability, exploit availability, affected code paths, deployment context, exposure to untrusted input, existing mitigations and actual impact should also be considered.

A HIGH vulnerability in unreachable code may have lower practical risk than a lower-severity issue on a public attack surface.

### b) Why does a distroless image help?

A distroless image contains fewer operating-system packages and utilities. This reduces the attack surface and the number of packages that can contain vulnerabilities.

### c) When should `.trivyignore` be used?

Only for documented and justified exceptions, ideally with an owner, reason and review or expiration date. Using it simply to make a scan look clean would hide risk rather than reduce it.

### d) How does an SBOM help during an incident?

An SBOM provides an inventory of exact software components and versions. After disclosure of a vulnerability such as Log4Shell, it can help quickly determine whether an affected library or version is present.

### e) Why centralize security headers in middleware?

Middleware applies the policy consistently to all routes, including responses generated outside individual handlers such as 404 responses.

### f) What does `Content-Security-Policy: default-src 'none'` do?

It blocks resource loading by default, including scripts, styles and images, unless explicitly allowed. It can be appropriate for a pure API but would need additional directives for a normal web UI.

### g) Why not automatically accept all informational findings?

Informational findings can still reveal configuration problems or conditions that become security-relevant in another deployment context. Automatically accepting everything creates noise and can hide issues that deserve review.

## 10. Bonus — govulncheck as a PR gate

Added `.github/workflows/govulncheck.yml`.

The workflow runs automatically for Pull Requests targeting `main` and can also be started manually with `workflow_dispatch`.

The CI job:

1. checks out the repository;
2. installs Go 1.27.1;
3. installs `golang.org/x/vuln/cmd/govulncheck@latest`;
4. runs `govulncheck ./...` from the `app` directory.

A non-zero `govulncheck` exit code fails the GitHub Actions job, making it a PR security gate.

Local verification:

    Go: go1.27.1
    Scanner: govulncheck@v1.8.0
    DB: https://vuln.go.dev
    DB updated: 2026-10-07 14:10:51 +0000 UTC

    No vulnerabilities found.
    Exit code: 0

## 11. Final status

| Check | Result |
|---|---|
| Trivy image HIGH | 0 |
| Trivy image CRITICAL | 0 |
| Trivy filesystem applicable HIGH/CRITICAL | 0 |
| Trivy config misconfigurations | 0 |
| CycloneDX SBOM | Generated |
| ZAP FAIL findings | 0 |
| ZAP WARN findings | 2, triaged |
| Go tests | Passed |
| govulncheck | Passed |
| Bonus PR gate | Added |

All required Lab 9 security scanning, triage, remediation and documentation tasks were completed. The optional `govulncheck` CI/PR gate was also added.
