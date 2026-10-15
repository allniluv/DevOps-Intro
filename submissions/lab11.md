# Lab 11 — Reproducible Builds with Nix

## Task 1 — Reproducible Nix build

### flake.nix

The project uses Nix flakes with pinned nixpkgs input and supports both `aarch64-darwin` and `x86_64-linux`.

The generated `flake.lock` pins the `nixpkgs` input to revision:

    b6018f87da91d19d0ab4cf979885689b469cdd41

The main QuickNotes derivation uses `buildGoModule` with `CGO_ENABLED=0` and stripped linker flags.

### Build verification

`nix flake show --all-systems` completed successfully and showed packages and development shells for both `aarch64-darwin` and `x86_64-linux`.

`nix flake check` completed successfully on the development machine.

Native development environment:

    go1.25.10 darwin/arm64
    gopls v0.20.0
    golangci-lint 2.6.2

Two independent `x86_64-linux` builds produced the same Nix store hash:

    sha256:1hv80kblj0zqcz82z0wihvxz63kylgwkqqgv5naykf0ar4f26w8k
    sha256:1hv80kblj0zqcz82z0wihvxz63kylgwkqqgv5naykf0ar4f26w8k

This demonstrates that the QuickNotes binary build is reproducible across independent build environments.

### Health check

The resulting binary was started and checked using `/health`:

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"notes":4,"status":"ok"}

### Design questions

**a. Why is `flake.lock` important for reproducibility?**

`flake.lock` records exact revisions of flake inputs. This ensures that different builds use the same versions of the dependencies instead of resolving potentially different revisions over time.

**b. Why are two independent builds useful?**

A single successful build only demonstrates that one environment can produce the artifact. Building independently twice and obtaining the same hash provides evidence that the artifact does not depend on accidental properties of one environment.

**c. Why is `CGO_ENABLED=0` useful here?**

Disabling CGO makes the Go binary independent of the host C compiler and system libraries. This reduces environmental dependencies and makes the build easier to reproduce.

**d. Why are the target systems specified explicitly?**

The project is developed on Apple Silicon (`aarch64-darwin`) while the deployment image targets Linux (`x86_64-linux`). Explicitly defining both systems prevents building an artifact for an unintended platform.

---

## Task 2 — Reproducible OCI image

The same `flake.nix` defines an OCI/Docker image using `pkgs.dockerTools.buildImage`.

The image configuration uses:

    Entrypoint = [ "/bin/quicknotes" ];

    ExposedPorts = {
      "8080/tcp" = {};
    };

    User = "1000:1000";

    Env = [
      "ADDR=:8080"
      "DATA_PATH=/data/notes.json"
      "SEED_PATH=/app/seed.json"
    ];

The image has `/bin/quicknotes` as its entrypoint, exposes port `8080`, and runs as the non-root user `1000:1000`.

Two independent Nix image builds produced identical SHA-256 digests:

    bf52ea517297861bff18bfb0b23f039a0b25cdf36511df474c2d2c5e1be0c13d
    bf52ea517297861bff18bfb0b23f039a0b25cdf36511df474c2d2c5e1be0c13d

The resulting image was loaded into Docker and successfully started.

The image health check returned:

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"notes":4,"status":"ok"}

### Image size comparison

The Nix image size in this experiment was approximately 9.55 MB.

The Lab 6 image size was approximately 5.76 MB.

Therefore, the Nix image was larger in this experiment. The trade-off is that the Nix image was reproducible bit-for-bit.

### Lab 6 comparison

Two fresh `docker build --no-cache` builds from Lab 6 produced different image digests:

    sha256:3df4f3b6156900b3528091a8c4124c37358f3502be5ba9685141014dea29d561
    sha256:4c80a1eec70096468957016e2ab8fb9ad8714942b159e5631e1b69044870d089

Saved Lab 6 image tarballs also produced different SHA-256 hashes:

    a7c658bd805d6db142450ba31d17f70dc7c3682fa4efacc43585c8a77d0cb62d
    bc0b5b1aa55310c1d0d51b1ad7b4c6a320a2e7f2e8b5e10223fb6fe637b41dea

Therefore, the Lab 6 Docker build was not bit-for-bit reproducible in this experiment.

### Design questions

**e. Why use `dockerTools.buildImage` instead of a Dockerfile?**

`dockerTools.buildImage` creates the container image directly from Nix derivations. This makes the image contents and metadata part of the reproducible Nix build.

**f. Why does the Nix image use a non-root user?**

The image runs as `1000:1000` instead of root. This follows the principle of least privilege and reduces the impact of a possible application compromise.

**g. Why can the Nix image be larger than the Lab 6 image?**

Reproducibility and image size are separate goals. The Nix image contains the files required by the Nix-built environment, so it can be larger than a highly minimized Docker image.

---

## Bonus — CI reproducibility check

The CI workflow is stored in `.github/workflows/nix-repro.yml`.

The workflow contains two independent parallel build jobs. Each job checks out the repository, installs Nix, builds `.#docker`, and calculates the SHA-256 digest of the resulting artifact. A third job compares the two outputs.

The Nix installer action is pinned to commit:

    3138316df39ed29be04236d7ffc686fa525866aa

### Green CI run

Final successful run:

https://github.com/allniluv/DevOps-Intro/actions/runs/38745365199

The two builds produced the same digest and the comparison job reported:

    OK: Nix builds are reproducible

### Intentional red CI run

To verify that the CI check can detect a reproducibility problem, `SOURCE_DATE_EPOCH` was intentionally changed between Build A and Build B.

Red run:

https://github.com/allniluv/DevOps-Intro/actions/runs/38745012037

The two builds produced different image digests and the comparison job failed with:

    ERROR: Nix builds are NOT reproducible

After the test, the reproducible configuration was restored and the final green CI run succeeded.

### Design questions

**h. Why should the two CI builds run on independent runners?**

Independent runners reduce the possibility that both builds share local build state or cached artifacts. This makes the reproducibility test stronger.

**i. Why compare the complete image artifact instead of only the application binary?**

The final deployment artifact is the container image. Comparing the complete image digest checks the binary, filesystem contents, and image metadata together.

**j. Why intentionally create a failing CI run?**

A negative test demonstrates that the workflow is actually capable of detecting a reproducibility violation. It verifies that the comparison step fails when the two builds produce different artifacts.
