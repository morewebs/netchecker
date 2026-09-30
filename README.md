# NetChecker

Continuous connection monitoring for Android, Windows, and Linux. Check what is
reachable, inspect the evidence, and compare results before and after changing
your network or VPN.

## Checks

Three independent lanes run continuously, with sequential checks within each lane:

- **Websites** — certificate-verified HTTPS reachability, with HTTP response codes
  and measured connection stages. HEAD falls back to GET when unsupported.
- **DNS** — resolver response latency and address lookups, shown separately.
  Queries validate responses and fall back to TCP for truncated UDP answers.
- **Advanced** — IPv4/IPv6 TCP, TLS handshakes, and edge checks. Handshake-only
  checks explicitly state that certificate identity is not verified.

Search, filter, favorite, or exclude targets without reordering live results.
Phones open full-screen details; wide desktop windows keep a detail inspector
beside the monitor. Pause/Resume, keyboard shortcuts, large-text layouts, and
reduced-motion support are included.

Settings include probe timing, custom HTTPS targets, the DNS comparison hostname,
privacy, and update checks. Desktop socket binding is distinct from system DNS
resolution. Compact mode and always-on-top are independent controls.

## Session data and reports

Results remain in memory: up to 120 recent measurements per target, session
counters, a bounded change log, and one captured comparison baseline. Restarting
clears these; settings persist. Monitoring configuration changes start a new
measurement context. Android monitoring is foreground-based.

Preview and copy Markdown, CSV, plain text, or schema-versioned JSON reports. Redaction is on
by default and remains enabled in privacy mode. Reports cover every probe category.
HTTP errors, private DNS answers, and unavailable IPv6 are observations, not proof
of censorship or a failed connection overall.

## Run

```bash
flutter pub get
flutter run
```

The project uses Flutter 3.44.2 / Dart 3.12.2. Regression checks use local network
fixtures and fake transports rather than depending on public internet availability.

```bash
flutter analyze --no-pub
flutter test --no-pub
```

See [the overhaul plan](docs/overhaul-plan.md) and
[validation progress and remaining limitations](docs/overhaul-progress.md).

## CI

GitHub Actions builds APK, Windows zip, and Linux zip/deb/rpm on every commit.

- Nightly prerelease on `main`
- GitHub Release on tags `v*`

Optional Android signing secrets: `KEYSTORE` (base64 `.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Without them, CI uses the debug key.

## License

MIT
