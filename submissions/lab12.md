# Lab 12 — Bonus: WebAssembly Containers — A QuickNotes Endpoint on Spin

## Goal

Build a small QuickNotes-related HTTP endpoint as a WebAssembly component using Go, TinyGo, and Spin. Serve `/time` with Moscow time information, then compare the WebAssembly/Spin implementation with the Lab 6 Docker deployment in terms of artifact size, cold-start time, and warm request latency.

## Changes

- Added a Spin HTTP component under `wasm/moscow-time/`.
- Implemented a `/time` endpoint returning Unix time, RFC3339 UTC time, and Moscow `HH:MM`.
- Built the component with TinyGo for `wasip1` using `-buildmode=c-shared`.
- Configured Spin with no allowed outbound hosts.
- Added a standalone WASI CLI implementation under `wasm/wasm-cli/`.
- Built and executed the CLI module with TinyGo and Wasmtime.
- Benchmarked warm latency with Hyperfine.
- Measured cold-start latency using five independent runs.
- Compared the WASM artifact with the Lab 6 `quicknotes:lab6` Docker image.

## Spin HTTP Component

The Spin component is located in `wasm/moscow-time/`.

The endpoint is `GET /time`.

Example response:

{
  "unix": 1792096354,
  "iso": "2026-10-15T20:32:34Z",
  "hour_minute": "23:32"
}

The `hour_minute` value is calculated from UTC using a fixed UTC+3 offset for Moscow.

The Spin component is configured with `allowed_outbound_hosts = []`, so the component does not have access to outbound network hosts.

### Build

`spin build`

The component was built successfully with TinyGo 0.41.1 and Go 1.26.

Resulting artifact: `main.wasm — 521 KB`.

### Run

Spin was run on port 3001 because port 3000 was already occupied on the host.

`spin up --listen 127.0.0.1:3001`

The endpoint was verified with:

`curl http://127.0.0.1:3001/time`

and returned HTTP 200 with valid JSON.

## Performance Evaluation

### Test rig

- Host: macOS on Apple Silicon
- Spin: 3.4.0
- TinyGo: 0.41.1
- Go: 1.26.9
- Hyperfine: 2.0.0
- Docker image: `quicknotes:lab6`
- Spin endpoint: `http://127.0.0.1:3001/time`
- Docker endpoint: `http://127.0.0.1:18081/health`

Warm latency was measured with 5 warmup runs and 50 measured runs.

Cold start was measured using 5 independent starts and successful first responses.

## Results

| Metric | Lab 6 Docker | Lab 12 WASM/Spin |
|---|---:|---:|
| Artifact size | 21.9 MB | 521 KB |
| Cold start p50 | 174.011 ms | 26.014 ms |
| Warm latency p50 | 11.423 ms | 10.566 ms |
| Warm latency p95 | 15.796 ms | 16.946 ms |

### Warm latency

Spin/WASM: p50 = 10.566 ms, p95 = 16.946 ms.

Docker: p50 = 11.423 ms, p95 = 15.796 ms.

The warm request latency is very similar for both implementations. Spin/WASM has a slightly lower p50, while Docker has a slightly lower p95 in this measurement.

### Cold start

Spin/WASM measurements:

- 26.360 ms
- 25.419 ms
- 25.992 ms
- 26.014 ms
- 26.371 ms

Cold-start p50: `26.014 ms`.

Docker measurements:

- 201.336 ms
- 174.011 ms
- 173.840 ms
- 167.360 ms
- 175.120 ms

Cold-start p50: `174.011 ms`.

The Spin/WASM implementation therefore had a substantially lower cold-start latency in this local test.

### Artifact size

The Spin component was `521 KB`.

The Lab 6 Docker image was `21.9 MB`.

The WASM artifact is therefore much smaller than the Docker image used for comparison.

## Questions

### a. How does server-side WASM differ from browser WASM?

Browser WASM is normally compiled for a JavaScript/browser environment and interacts with browser APIs through JavaScript. Server-side WASM targets a WASI environment and does not provide browser APIs such as the DOM. Instead, it uses WASI and the host runtime to provide controlled server-side capabilities.

### b. Why is `-buildmode=c-shared` used?

`-buildmode=c-shared` produces the module in the form expected by the Spin Go SDK and its host integration. It allows the Go/TinyGo code to be packaged as a WebAssembly component that Spin can load and invoke as an HTTP handler.

### c. How does WASM capability security compare with Docker `--network none`?

WASM uses explicit capabilities. In this lab, `allowed_outbound_hosts = []` means that the component has no allowed outbound hosts.

Docker `--network none` disables container networking at the container level. WASM capability security can be more granular because individual capabilities can be granted explicitly rather than simply enabling or disabling the whole network namespace.

### d. What TinyGo standard-library gaps affected the implementation?

The implementation avoided timezone database functionality such as `time.LoadLocation("Europe/Moscow")` and instead used a fixed UTC+3 offset.

The JSON response also uses a simple struct with JSON tags, avoiding more complex reflection-heavy patterns.

### e. What dominates container and WASM cold start?

For the Docker implementation, cold start includes container setup such as image/container initialization, process startup, and networking setup.

For Spin/WASM, cold start mainly involves loading and instantiating the WebAssembly module and initializing the runtime/component.

These measurements represent time from starting the runtime to receiving the first successful local HTTP response.

### f. When is WASM useful for lightweight services, and when is Docker better?

WASM is useful for lightweight HTTP services, functions, edge workloads, fast-starting workloads, and environments where strong sandboxing and low resource overhead are important.

Docker is preferable when an application requires a full Linux userspace, complex native dependencies, system packages, mature container tooling, or workloads that depend heavily on the traditional container ecosystem.

### g. How does multi-tenant WASM improve isolation?

A WASM module does not automatically receive unrestricted access to the host filesystem, network, or processes. Access is controlled by capabilities granted by the host runtime.

For example, malicious tenant code attempting to read host files or connect to arbitrary external services can be blocked when those capabilities are not granted.

## Bonus: Standalone WASI CLI

A standalone WASI CLI implementation was added under `wasm/wasm-cli/`.

It reads `REQUEST_METHOD` and `PATH_INFO` and returns the same `/time` JSON response.

### Build

`tinygo build -o main.wasm -target=wasi -no-debug ./main.go`

Artifact size: `373 KB`.

### Run

`wasmtime run --env REQUEST_METHOD=GET --env PATH_INFO=/time main.wasm`

Example output:

`Status: 200 OK`

`Content-Type: application/json`

`{"unix":1792096841,"iso":"2026-10-15T20:40:41Z","hour_minute":"23:40"}`

Five cold-start measurements were:

- 57.460 ms
- 25.035 ms
- 24.620 ms
- 24.831 ms
- 24.873 ms

The cold-start p50 was `25.035 ms`.

The first invocation was slower than the following runs.

### h. Why cannot the Spin component be executed directly with `wasmtime run`?

The Spin module is an HTTP WebAssembly component that exports an HTTP handler expected by the Spin host. It is not a standalone WASI CLI program with a traditional `_start` entry point.

Therefore it requires a compatible component host such as Spin.

The standalone bonus module is different: it is a WASI CLI module with a `_start` entry point and can be executed directly with Wasmtime.

### i. What does Spin add on top of the Wasmtime runtime?

Spin provides the application and HTTP service layer around the WebAssembly runtime. It handles HTTP routing, component lifecycle, request handling, configuration, and capability policies.

Wasmtime provides the lower-level WebAssembly/WASI runtime needed to execute the module.

### j. When would `wasmtime run` be preferable to Spin?

`wasmtime run` is suitable for short-lived standalone WASI programs, command-line utilities, batch jobs, or one-off tasks.

Spin is better suited for persistent HTTP services and microservices that need routing, lifecycle management, and repeated request handling.

## Conclusion

The experiment shows that the Spin/WASM implementation can provide a much smaller artifact and substantially faster cold starts than the Lab 6 Docker image, while maintaining similar warm request latency.

In this test:

- WASM artifact: 521 KB vs 21.9 MB Docker image.
- Cold-start p50: 26.014 ms vs 174.011 ms.
- Warm p50: 10.566 ms vs 11.423 ms.
- Warm p95: 16.946 ms vs 15.796 ms.

The results demonstrate the main advantage of WebAssembly for this type of lightweight service: small artifacts, fast startup, and sandboxed execution. Docker remains more suitable for applications requiring a full Linux environment or complex system-level dependencies.
