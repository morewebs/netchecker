# NetChecker overhaul

Approved 2026-09-30. Continuous probing is the primary experience. Android and
Windows have equal priority; Linux keeps the desktop feature set. Results,
history, events and comparisons live only in memory. Settings persist. English
copy is centralized for future translation. Keep Flutter 3.44.2 / Dart 3.12.2.

## Baseline and audit

The original app has three asynchronous lanes (websites, DNS latency, and
protocol/edge/DNS comparison), a ChangeNotifier engine, native desktop window
channels, and shared phone/desktop result widgets. Analysis, tests and a Windows
debug build passed before changes. Existing screenshots are stale.

Confirmed defects to address:

- Raw IP history keys mix DNS, edge and DNS-comparison measurements.
- Checking replaces the completed observation; discarded work can leave stale
  checking states. Manual checks race automatic work and disposal.
- Deep HTTP exceptions fabricate status 200. Ordinary HTTPS accepts invalid
  certificates. Bound HTTPS connections return a plain socket.
- DNS responses lack sender/header/question/rcode validation and lose records.
- Private addresses, HTTP 403 and resets are presented as proven interference.
- Phase timings measure separate connections while appearing to describe one.
- Exports omit/misidentify categories and do not consistently redact or escape.
- Traceroute fallback invents hops; platform/adapter limitations are concealed.
- Privacy masks only some labels, auto-update preference is ineffective,
  update assets are selected ambiguously, and desktop feedback lacks a Scaffold.
- Pinning changes window dimensions, controls are too small, and the root app
  rebuilds on every probe. Product/design documents no longer match the app.

## Implementation contract

1. Use category-aware ProbeKey identities, immutable completed observations,
   independent execution states, bounded histories and separate session totals.
2. Inject transport/clock, cancel and invalidate work on pause/context changes,
   deduplicate automatic/manual checks, and retain sequential independent lanes.
3. Measure verified HTTPS on one connection, bound all work, clean up resources,
   validate DNS, and report evidence rather than inferred censorship.
4. Build a readable live monitor with Websites / DNS / Advanced views, stable
   ordering, search, filters, favorites and enabled targets. Keep summary,
   pause/resume, context and freshness visible. On wide desktop use an inspector;
   on phones/narrow windows open details as a page.
5. Include session changes and one captured comparison baseline, honest metrics
   and phase details, grouped settings, export preview/redaction, and explicit
   unsupported/error states. Preserve settings with migration.
6. Evolve the dark Poppins/Space Mono identity: readable type, restrained colors,
   consistent controls, keyboard access, semantics, large text and reduced motion.
   Keep compact mode independent of always-on-top and restore previous bounds.

## Milestones

- M1: audit, regression tests, baseline documentation.
- M2: models, settings migration, transport, scheduler, reports, capabilities.
- M3: theme and adaptive live monitor.
- M4: details, comparisons, settings, reporting, updates and native integration.
- M5: deterministic tests, analysis, native builds/visual review, documentation.

## Acceptance

Cover DNS errors/malformed packets, TLS rejection, HTTP failures/HEAD fallback,
timeouts and bound connections with local fixtures or fakes. Cover pause/resume,
disposal, context changes, removal, duplicate checks and category independence.
Verify all report formats, redaction, in-memory lifetime, bounded monitoring,
stable selection/scroll, phone/compact/wide layouts, large text, keyboard and
screen-reader affordances. Build Windows and Android locally; report Linux
validation honestly. Capture actual native UI before claiming visual sign-off.

Foreground Android monitoring only; no background service, account, backend or
automatic network reconfiguration. Keep the existing default target catalog.
Remove dormant freeze/round-limit preferences; use an explicit session baseline.

## Delivery discipline

Record completed changes, tests and unresolved limitations in
`overhaul-progress.md` after each milestone. Update README, PRODUCT and DESIGN
from the final implementation. No release publication is part of this change.
