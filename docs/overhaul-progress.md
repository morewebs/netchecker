# Overhaul progress

## 2026-09-30 — implementation started

- [x] Inspected Dart application, probe code, tests, platform integration and CI.
- [x] Confirmed audience, equal Android/Windows priority, continuous monitoring,
  session-only results and English-first copy.
- [x] Baseline: `flutter analyze --no-pub`, `flutter test --no-pub` and
  `flutter build windows --debug --no-pub` passed.
- [x] Recorded approved implementation contract and audit.
- [x] M1: reproduced two metrics regressions: checking inflated both totals and failures.
- [x] M2 implementation: category-aware identity, separate execution/observations,
  cancellation, injectable transport/clock, bounded histories, session counters,
  validated DNS, verified HTTPS and complete/redactable schema-v2 reports.
- [x] M3 implementation: shared adaptive live monitor, readable theme, stable
  lists, category summaries, search/filter/favorites, phone details and desktop inspector.
- [x] M4 implementation: session baseline/events, grouped settings, report preview,
  honest route tracing, independent compact/pin controls and startup update checks.
- [x] M2–M4 deterministic regression and widget coverage implemented.
- [ ] M2–M4 native interaction checks.
- [ ] M5: native builds, regression/accessibility checks and visual review.

## Validation limits

Computer Use reported a physical Escape stop during Windows inspection. Native
screenshots and the independent finish review remain outstanding; existing review
captures predate this implementation and are not sign-off evidence.

Both Windows and Android debug builds completed locally. Linux validation was
attempted through WSL: Debian's backing disk was unavailable, and Apron-Verify's
package manager reported an interrupted dpkg installation before required GTK
dependencies could be installed. No Linux build or packaging success is claimed.
The existing Linux CI build remains the supported validation path.

README now describes the implemented behavior. Final native visual review and
the PRODUCT/DESIGN documentation refresh remain outstanding.

## Pre-commit verification — 2026-09-30

- Final checks: `flutter analyze --no-pub` passed, all 52 tests passed,
  `flutter build windows --release --no-pub` passed, and
  `flutter build apk --debug --no-pub` passed. The debug Windows rebuild could
  not replace files while a debug copy was running, so the final validation
  used a separate release output. Android emits future Gradle/AGP/Kotlin support
  warnings; the existing toolchain was retained as planned.
- Removed obsolete APK download/install code, dependencies and Android install
  permission; updates use the platform release asset in the browser.
- Fixed a cleanup race so successful transports do not cancel their caller's
  scheduler token; local HTTPS, TLS and DNS fixtures cover it.
- Sorted adapter inventory to avoid spurious measurement contexts and clarified
  foreground-resume wording. Unattempted HTTPS timing stages remain absent.
- Added large-text, privacy/reporting, target exclusion, comparison, settings
  validation and update asset/version regression checks.
- Large-text tests caught overflow in monitor controls and the settings footer;
  the monitor uses scrollable content with a pinned monitoring action at large
  text sizes, and the settings footer stacks when space is limited.
- Corrected the Windows bounds handler to use portable C++ min/max calls.
- User requested committing this snapshot to main and pushing. The existing CI
  includes a nightly prerelease after all main-branch build jobs succeed; no
  manual release or version bump is included.

## Implementation decisions

- HTTPS response codes (including 4xx/5xx) establish server reachability, with
  an application-response warning. No result asserts censorship or poisoning.
- DNS response latency and successful DNS resolution are different outcomes.
- Retain 120 recent observations per target and 200 session changes. Separate
  counters retain completed-check totals for the current network context.
- A context change clears current observations/counters, cancels old work and
  preserves the explicitly captured baseline for comparison.
- HTTP HEAD falls back to a bounded GET for 405/501. Response headers establish
  reachability; response bodies are not downloaded without a bound.
- Route tracing uses system routing and no third-party enrichment. Unsupported
  platforms and missing commands return explanatory states, never invented hops.
- Update downloads open the platform release asset in the user's browser.
  Android requires a universal APK; otherwise the release page lets the user
  choose the appropriate ABI. The app does not silently choose a random APK.
