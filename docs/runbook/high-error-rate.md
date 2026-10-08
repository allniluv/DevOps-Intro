# QuickNotes High Error Rate Runbook

## Meaning

`QuickNotesHighErrorRate` means that the HTTP 4xx/5xx error ratio for QuickNotes has remained above 5% for at least 5 minutes.

## Triage

1. Check the alert and current error ratio in Prometheus. Confirm that `QuickNotesHighErrorRate` is firing and inspect the current value of the error-rate expression.

2. Inspect QuickNotes response-code metrics to identify which status codes are increasing:
   `quicknotes_http_responses_by_code_total{code=~"4..|5.."}`.

3. Check QuickNotes health and container status:
   `curl http://localhost:8080/health`
   and
   `docker compose ps`.

4. Inspect recent QuickNotes logs for request handling or application errors:
   `docker compose logs --tail=200 quicknotes`.

## Mitigations

1. If the error rate is caused by a bad deployment or configuration change, stop further rollout and restore the last known-good application configuration or image.

2. If the errors are caused by malformed or unexpected client traffic, identify the offending request pattern and reduce or block that traffic while preserving legitimate requests.

3. If the service is unhealthy, restart the affected QuickNotes container and verify `/health` and the Prometheus target before considering the incident resolved.

## Resolution verification

After mitigation:

1. Confirm that the error ratio falls below 5%.
2. Confirm that `QuickNotesHighErrorRate` leaves the firing state.
3. Verify that the QuickNotes Prometheus target is `up`.
4. Confirm that the Golden Signals dashboard shows normal traffic, errors, and saturation.

## Post-incident

Record the incident as a blameless postmortem: document the timeline, impact, contributing conditions, detection, response, recovery, and concrete follow-up actions. The postmortem should focus on improving the system and process rather than assigning blame.

See the [Lecture 1 — Blameless Postmortems](../../lectures/lec1.md) material for the course's postmortem approach.
