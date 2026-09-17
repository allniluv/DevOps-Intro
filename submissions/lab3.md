# Lab 3 — CI/CD: A PR-Gated Pipeline for QuickNotes

## 1. CI/CD pipeline

The QuickNotes project uses GitHub Actions as the CI system.

The workflow is triggered by:

* pushes to `main`;
* pull requests targeting `main`;
* changes under `app/**` or `.github/workflows/ci.yml` for pull requests.

The workflow uses three independent jobs:

* `vet` — runs `go vet ./...`;
* `test` — runs `go test -race -count=1 ./...`;
* `lint` — runs `golangci-lint run` using `golangci-lint v2.5.0`.

All jobs run on the pinned `ubuntu-24.04` runner.

The final pipeline tests Go 1.23 and Go 1.24 using a matrix for the `vet` and `test` jobs.

All third-party GitHub Actions are pinned to full commit SHAs with human-readable version comments.

The workflow declares:

```yaml
permissions:
  contents: read
```

This follows the principle of least privilege.

## 2. Caching

The final pipeline caches:

* Go module cache: `~/go/pkg/mod`
* Go build cache: `~/.cache/go-build`

The cache key includes the operating system, Go version, and the hash of `app/go.mod`.

The project currently has no third-party Go dependencies and does not contain a `go.sum` file. Therefore, the cache has limited work to do in this particular repository.

Automatic caching in `actions/setup-go` is disabled because the cache is implemented explicitly with `actions/cache`.

## 3. Matrix testing

The `vet` and `test` jobs use the following matrix:

```yaml
matrix:
  go-version: ['1.23', '1.24']
```

The matrix runs in parallel.

`fail-fast: false` is used so that a failure in one Go version does not cancel the other version. This provides complete compatibility information from the same workflow run.

## 4. Path filtering

Pull request workflows are limited to relevant changes:

```yaml
paths:
  - 'app/**'
  - '.github/workflows/ci.yml'
```

Therefore, documentation-only changes do not start the CI pipeline.

This reduces unnecessary CI usage while still running CI when application code or the workflow itself changes.

# 5. Design questions

## a) Why pin the runner to `ubuntu-24.04`?

Using `ubuntu-24.04` instead of `ubuntu-latest` makes the CI environment more predictable.

The `ubuntu-latest` label can move to a newer Ubuntu release in the future. Pinning the runner reduces unexpected changes caused by automatic runner-image updates and makes CI results easier to reproduce.

## b) Why split the pipeline into independent jobs?

The checks are separated into `vet`, `test`, and `lint` jobs so they can run independently and in parallel.

This makes failures easier to identify because GitHub reports which specific check failed.

Independent jobs also allow different jobs to use different configurations or matrices when necessary.

The trade-off is that each job requires its own runner, so splitting jobs can increase runner startup overhead.

## c) What does SHA pinning protect against?

Pinning an action to a full commit SHA means that the workflow executes a specific immutable revision of that action rather than following a moving tag.

For example:

```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

This reduces the risk that a mutable tag is later moved to a malicious or compromised commit.

This is a supply-chain security measure because third-party workflow actions execute code with the permissions available to the workflow.

## d) What does `permissions` mean and why use least privilege?

The `permissions` section controls the permissions granted to the GitHub Actions `GITHUB_TOKEN`.

The workflow uses:

```yaml
permissions:
  contents: read
```

The CI pipeline only needs to read repository contents. It does not need permission to write code, create releases, modify issues, or change repository settings.

Granting only the permissions required by the workflow reduces the potential impact if an action or workflow step is compromised.

## e) GitLab stages vs jobs/dependencies

GitHub Actions jobs are individual execution units that can run in parallel.

GitLab stages provide an ordering structure: jobs in a later stage normally wait for the previous stage to complete.

GitLab also supports explicit job dependencies, while GitHub Actions expresses dependencies between jobs using `needs`.

For this pipeline, independent checks do not need dependencies, so they can run concurrently.

## f) Why should cache keys depend on dependency inputs?

A dependency cache should change when the inputs that determine the dependencies change.

For Go projects, files such as `go.mod` and `go.sum` describe the dependency set.

If dependency inputs change, an old cache may no longer be valid. Including those files in the cache key prevents unrelated dependency states from sharing the same cache.

Build outputs should not be used as the primary dependency-cache key because they are generated artifacts rather than the source of dependency resolution.

In this project there is no `go.sum`, so the final cache uses the available `app/go.mod` dependency input.

## g) `fail-fast: false` vs `true`

With `fail-fast: true`, a failing matrix job can cancel other in-progress matrix jobs.

With `fail-fast: false`, all matrix combinations are allowed to finish.

For compatibility testing across Go 1.23 and Go 1.24, `fail-fast: false` is useful because it shows whether both versions pass even if one version fails.

The downside is that a failure can consume more CI time because other matrix jobs continue running.

## h) Cache poisoning risk and GitHub Actions protections

Cache poisoning occurs when an attacker causes malicious or incorrect data to be stored in a cache and later restored by another workflow.

This is particularly important for workflows processing untrusted pull requests.

GitHub Actions provides cache isolation mechanisms based on repository, branch, and cache scope. Cache keys should also be designed carefully so that unrelated or untrusted data is not accidentally reused.

The workflow should avoid restoring caches from untrusted sources when those caches could influence executable build artifacts.

# 6. CI timing measurements

Three configurations were measured using GitHub Actions.

| Configuration                  |     vet |    test | lint | Approx. wall-clock |
| ------------------------------ | ------: | ------: | ---: | -----------------: |
| Baseline — no cache, no matrix |    20 s |    24 s | 25 s |              ~25 s |
| Cache only                     |    37 s |    25 s | 18 s |              ~37 s |
| Cache + matrix                 | 23/35 s | 26/36 s | 28 s |              ~36 s |

The matrix configuration has two `vet` and two `test` jobs because Go 1.23 and Go 1.24 are tested in parallel.

Wall-clock time is approximately the duration of the longest parallel job, rather than the sum of all job durations.

# 7. Timing analysis

The measurements show that caching did not reduce wall-clock time in this small project.

The repository has no third-party Go dependencies, so there is little dependency-download work for the cache to accelerate. Runner startup and toolchain setup therefore represent a significant part of the observed time.

The matrix also increases the amount of CI work because `vet` and `test` are executed for two Go versions. Although these jobs run in parallel, each job requires a separate runner.

Therefore, the measured results are specific to this small repository and should not be interpreted as a general statement that caching or matrix testing always makes CI slower.

# 8. Final pipeline status

The final workflow successfully passed all five checks:

* `vet (Go 1.23)` — passed
* `vet (Go 1.24)` — passed
* `test (Go 1.23)` — passed
* `test (Go 1.24)` — passed
* `lint` — passed

The final working tree was clean and the `feature/lab3` branch was synchronized with `origin/feature/lab3`.

# 9. Remaining verification

The final PR gate must also be verified through branch protection by requiring the CI status checks on `main`.

A deliberate CI failure should be introduced and observed as a blocked PR check, followed by a fix and a successful CI run.

