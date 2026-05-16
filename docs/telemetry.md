# Anonymous Usage Telemetry

Ping Island can optionally send a small amount of anonymous product telemetry to
Alibaba Cloud Simple Log Service (SLS). Telemetry is not uploaded until the user
confirms consent during first-run onboarding or later in Settings. The
"匿名使用统计" switch in Settings can disable it at any time.

## SLS Configuration

The first SLS target uses:

- Project: `ping-island-global`
- Logstore: `ping-island`
- Topic: `product-telemetry`
- Source: `ping-island-macos`

Set the SLS region endpoint host in `Config/LocalSecrets.xcconfig`:

```xcconfig
PING_ISLAND_TELEMETRY_SLS_HOST = ap-southeast-1.log.aliyuncs.com
```

Use the endpoint for the region where the `ping-island` project was created.
The console URL contains the project and logstore names, but not the region
endpoint.

The app writes with SLS WebTracking batch upload:

```text
POST https://ping-island-global.<region>.log.aliyuncs.com/logstores/ping-island/track
```

The target Logstore must have WebTracking enabled before client uploads are
accepted.

## Cost Controls

- Telemetry requires user consent and is disabled when the SLS host is empty.
- Events are batched, with a default flush interval of 60 seconds and batch
  size of 10.
- The default daily cap is 200 events per device.
- Startup and integration snapshots are throttled to avoid repeated uploads.
- Only allowlisted fields are serialized; unknown fields are dropped.
- Values are truncated to 160 characters and restricted to a conservative
  ASCII-safe character set.

## Event Allowlist

Current event names:

- `app_launched`
- `telemetry_preference_changed`
- `setting_changed`
- `hook_install_completed`
- `hook_reinstall_completed`
- `integration_status_snapshot`
- `session_detected`
- `session_completed`

Current fields describe only product behavior, such as app version, build,
distribution channel, macOS major version, architecture, language bucket,
surface mode, client type, ingress type, install result, duration bucket, and
tool count bucket.

## Explicitly Not Collected

Telemetry must not include:

- Prompts, responses, message previews, code, diffs, or terminal output.
- Project paths, file paths, repository names, usernames, hostnames, SSH
  targets, IP addresses, tmux identifiers, or terminal identifiers.
- Raw hook payloads, diagnostics contents, secrets, tokens, or API keys.
