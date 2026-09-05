import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../probe/engine.dart';
import '../../probe/models.dart';
import '../../theme.dart';
import '../keyboard/shortcuts.dart';
import 'latency_chart.dart';
import 'latency_histogram.dart';
import 'route_map_page.dart';
import 'waterfall_card.dart';

class ItemProfilePage extends StatefulWidget {
  const ItemProfilePage({
    super.key,
    required this.engine,
    required this.targetInfo,
    this.autoProbe = false,
  });

  final ProbeEngine engine;
  final ItemProfileInfo targetInfo;
  final bool autoProbe;

  static Future<void> open(
    BuildContext context, {
    required ProbeEngine engine,
    required ItemProfileInfo targetInfo,
    bool autoProbe = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ItemProfilePage(
          engine: engine,
          targetInfo: targetInfo,
          autoProbe: autoProbe,
        ),
      ),
    );
  }

  @override
  State<ItemProfilePage> createState() => _ItemProfilePageState();
}

class _ItemProfilePageState extends State<ItemProfilePage> {
  bool _isProbing = false;
  bool _liveMonitor = false;
  int _chartTab = 0;
  Timer? _liveTimer;
  PhaseBreakdown? _latestPhase;
  final FocusNode _profileFocusNode = FocusNode(debugLabel: 'ItemProfilePage');

  @override
  void initState() {
    super.initState();
    _loadInitialPhase();
    if (widget.autoProbe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerPing(silent: false);
        }
      });
    }
  }

  void _loadInitialPhase() {
    final samples = widget.engine.getHistory(widget.targetInfo.id);
    for (final s in samples.reversed) {
      if (s.phase != null) {
        _latestPhase = s.phase;
        break;
      }
    }
    if (_latestPhase == null) {
      final current = _getCurrentHit();
      if (current.status == HitStatus.ok && current.ms != null) {
        if (widget.targetInfo.category == ItemCategory.dns) {
          _latestPhase = PhaseBreakdown(dnsMs: current.ms);
        } else if (widget.targetInfo.category == ItemCategory.edge) {
          _latestPhase = PhaseBreakdown(tlsMs: current.ms);
        } else if (widget.targetInfo.category == ItemCategory.proto) {
          _latestPhase = PhaseBreakdown(tcpMs: current.ms);
        }
      }
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _toggleLiveMonitor(bool value) {
    setState(() => _liveMonitor = value);
    _liveTimer?.cancel();
    if (value) {
      _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isProbing && mounted) {
          _triggerPing(silent: true);
        }
      });
      _triggerPing(silent: true);
    }
  }

  Future<void> _triggerPing({bool silent = false}) async {
    if (_isProbing) return;
    if (!silent) setState(() => _isProbing = true);
    try {
      final sample = await widget.engine.runDeepProbe(widget.targetInfo);
      if (mounted) {
        setState(() {
          if (sample.phase != null) {
            _latestPhase = sample.phase;
          }
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isProbing = false);
      }
    }
  }

  Hit _getCurrentHit() {
    final id = widget.targetInfo.id;
    switch (widget.targetInfo.category) {
      case ItemCategory.domain:
        return widget.engine.domainHits[id] ?? Hit.idle;
      case ItemCategory.dns:
        return widget.engine.dnsHits[id] ?? Hit.idle;
      case ItemCategory.edge:
        return widget.engine.edgeHits[id] ?? Hit.idle;
      case ItemCategory.hunt:
        return widget.engine.huntHits[id] ?? Hit.idle;
      case ItemCategory.proto:
        return widget.engine.protoHits[id] ?? Hit.idle;
    }
  }

  Color _getStatusAccent(HitStatus status, bool isClean) {
    if (!isClean && status != HitStatus.idle) return kFail;
    switch (status) {
      case HitStatus.ok:
        return const Color(0xFF10B981);
      case HitStatus.timeout:
        return const Color(0xFFF59E0B);
      case HitStatus.fail:
        return kFail;
      case HitStatus.checking:
        return const Color(0xFF06B6D4);
      case HitStatus.idle:
        return const Color(0xFF06B6D4);
    }
  }

  Future<void> _copyReport(ItemMetrics metrics, List<ProbeSample> samples) async {
    final buf = StringBuffer();
    buf.writeln('Telemetry Report: ${widget.targetInfo.title}');
    buf.writeln('Target: ${widget.targetInfo.hostOrIp ?? widget.targetInfo.id}');
    buf.writeln('Category: ${widget.targetInfo.categoryLabel}');
    buf.writeln('Status: ${metrics.filterStatus}');
    buf.writeln('Avg Latency: ${metrics.avgMs > 0 ? "${metrics.avgMs.toStringAsFixed(1)}ms" : "N/A"}');
    buf.writeln('Success Rate: ${metrics.uptimePercent.round()}%');
    buf.writeln('Jitter (StdDev): ±${metrics.stdDevMs.toStringAsFixed(1)}ms');
    buf.writeln('Loss: ${metrics.lossPercent.round()}%');
    buf.writeln('Total Samples: ${metrics.totalChecks}');
    if (widget.targetInfo.explanation != null) {
      buf.writeln('Description: ${widget.targetInfo.explanation}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final currentHit = _getCurrentHit();
        final samples = widget.engine.getHistory(widget.targetInfo.id);
        final metrics = widget.engine.getMetrics(
          widget.targetInfo.id,
          currentHit: currentHit,
        );
        final accent = _getStatusAccent(currentHit.status, metrics.isClean);

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
            const SingleActivator(LogicalKeyboardKey.backspace): const EscapeIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonB): const EscapeIntent(),
            const SingleActivator(LogicalKeyboardKey.goBack): const EscapeIntent(),
            const SingleActivator(LogicalKeyboardKey.keyR): const PingNowIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const PingNowIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonA): const PingNowIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonX): const PingNowIntent(),
            const SingleActivator(LogicalKeyboardKey.keyT): const TracerouteIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonY): const TracerouteIntent(),
            const SingleActivator(LogicalKeyboardKey.keyA): const ToggleAutoIntent(),
            const SingleActivator(LogicalKeyboardKey.keyC): const CopyReportIntent(),
            const SingleActivator(LogicalKeyboardKey.digit1): const PrevTabIntent(),
            const SingleActivator(LogicalKeyboardKey.bracketLeft): const PrevTabIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonLeft1): const PrevTabIntent(),
            const SingleActivator(LogicalKeyboardKey.digit2): const NextTabIntent(),
            const SingleActivator(LogicalKeyboardKey.bracketRight): const NextTabIntent(),
            const SingleActivator(LogicalKeyboardKey.gameButtonRight1): const NextTabIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              EscapeIntent: CallbackAction<EscapeIntent>(
                onInvoke: (_) {
                  Navigator.pop(context);
                  return null;
                },
              ),
              PingNowIntent: CallbackAction<PingNowIntent>(
                onInvoke: (_) {
                  _triggerPing();
                  return null;
                },
              ),
              TracerouteIntent: CallbackAction<TracerouteIntent>(
                onInvoke: (_) {
                  RouteMapPage.open(
                    context,
                    target: widget.targetInfo.hostOrIp ?? widget.targetInfo.id,
                    title: widget.targetInfo.title,
                  );
                  return null;
                },
              ),
              ToggleAutoIntent: CallbackAction<ToggleAutoIntent>(
                onInvoke: (_) {
                  _toggleLiveMonitor(!_liveMonitor);
                  return null;
                },
              ),
              CopyReportIntent: CallbackAction<CopyReportIntent>(
                onInvoke: (_) {
                  _copyReport(metrics, samples);
                  return null;
                },
              ),
              PrevTabIntent: CallbackAction<PrevTabIntent>(
                onInvoke: (_) {
                  setState(() => _chartTab = 0);
                  return null;
                },
              ),
              NextTabIntent: CallbackAction<NextTabIntent>(
                onInvoke: (_) {
                  setState(() => _chartTab = 1);
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _profileFocusNode,
              autofocus: true,
              canRequestFocus: true,
              child: Scaffold(
                backgroundColor: kInk,
                appBar: AppBar(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Text(
                      widget.targetInfo.categoryLabel,
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        color: kPaper,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Trace Route (T)',
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => RouteMapPage.open(
                        context,
                        target: widget.targetInfo.hostOrIp ?? widget.targetInfo.id,
                        title: widget.targetInfo.title,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Reset Stats',
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        widget.engine.resetStats(widget.targetInfo.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Statistics reset for this item')),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Copy Report (C)',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => _copyReport(metrics, samples),
                    ),
                    const SizedBox(width: 12),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Identity & Status
                  _HeroBanner(
                    targetInfo: widget.targetInfo,
                    currentHit: currentHit,
                    metrics: metrics,
                    accentColor: accent,
                    isProbing: _isProbing,
                    liveMonitor: _liveMonitor,
                    onToggleLive: _toggleLiveMonitor,
                    onPingNow: () => _triggerPing(),
                    onTraceRoute: () => RouteMapPage.open(
                      context,
                      target: widget.targetInfo.hostOrIp ?? widget.targetInfo.id,
                      title: widget.targetInfo.title,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. About This Item Card
                  _AboutCard(
                    targetInfo: widget.targetInfo,
                  ),
                  const SizedBox(height: 14),

                  // 3. 4-Card Stats Grid
                  _KpiMetricGrid(metrics: metrics, accentColor: accent),
                  const SizedBox(height: 14),

                  // 4. Chart / Histogram Switcher & Visualization (Segmented Tabs)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kLine),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _chartTab = 0),
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _chartTab == 0 ? const Color(0xFF27272A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'PING HISTORY',
                                  style: TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontSize: 10,
                                    fontWeight: _chartTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                    color: _chartTab == 0 ? kPaper : kMute,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _chartTab = 1),
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _chartTab == 1 ? const Color(0xFF27272A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'FREQUENCY HISTOGRAM',
                                  style: TextStyle(
                                    fontFamily: 'Space Mono',
                                    fontSize: 10,
                                    fontWeight: _chartTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                    color: _chartTab == 1 ? kPaper : kMute,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_chartTab == 0)
                    ItemLatencyChart(
                      samples: samples,
                      accentColor: accent,
                      height: 170,
                    )
                  else
                    LatencyHistogramCard(
                      samples: samples,
                      accentColor: accent,
                    ),
                  const SizedBox(height: 14),

                  // 5. Connection Steps Breakdown
                  ConnectionWaterfallCard(
                    phase: _latestPhase,
                    targetInfo: widget.targetInfo,
                    isProbing: _isProbing,
                    onRunDeepProbe: () => _triggerPing(),
                  ),
                  const SizedBox(height: 14),

                  // 6. Details Table
                  _DetailsCard(
                    targetInfo: widget.targetInfo,
                    engine: widget.engine,
                      phase: _latestPhase,
                    metrics: metrics,
                  ),
                  const SizedBox(height: 14),

                  // 7. Recent Pings Log
                  _RecentAuditLog(samples: samples, accentColor: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.targetInfo,
    required this.currentHit,
    required this.metrics,
    required this.accentColor,
    required this.isProbing,
    required this.liveMonitor,
    required this.onToggleLive,
    required this.onPingNow,
    required this.onTraceRoute,
  });

  final ItemProfileInfo targetInfo;
  final Hit currentHit;
  final ItemMetrics metrics;
  final Color accentColor;
  final bool isProbing;
  final bool liveMonitor;
  final ValueChanged<bool> onToggleLive;
  final VoidCallback onPingNow;
  final VoidCallback onTraceRoute;

  String _getDisplayTag() {
    if (targetInfo.category == ItemCategory.edge) {
      return 'CDN';
    }
    if (targetInfo.tag != null && targetInfo.tag!.isNotEmpty) {
      if (targetInfo.tag!.length <= 4) {
        return targetInfo.tag!;
      }
    }
    final clean = targetInfo.title.replaceAll(RegExp(r'^(https?://|www\.)'), '');
    if (clean.length <= 3) return clean.toUpperCase();
    final parts = clean.split('.');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 3 ? 3 : parts[0].length).toUpperCase();
    }
    return clean.substring(0, 2).toUpperCase();
  }

  String _getHumanStatusText() {
    if (currentHit.status == HitStatus.checking) {
      return 'Pinging...';
    }
    if (currentHit.status == HitStatus.ok) {
      final ms = currentHit.ms;
      return ms != null && ms > 0 ? 'Online · ${ms}ms' : 'Online';
    }
    if (currentHit.status == HitStatus.timeout) {
      return 'Timed Out';
    }
    if (currentHit.status == HitStatus.idle) {
      return 'Checking...';
    }
    final detail = currentHit.detail ?? '';
    if (currentHit.hasPrivateIp || isPrivateOrPoisonedIp(detail)) {
      return detail.isNotEmpty
          ? 'Blocked (DNS Poisoning: $detail)'
          : 'Blocked (DNS Poisoning)';
    }
    if (detail.contains('rst')) return 'Connection Reset';
    if (detail.contains('tls') || detail.contains('hs')) return 'SSL / TLS Error';
    if (detail.contains('nx')) return 'DNS Failed';
    return detail.isNotEmpty ? 'Failed ($detail)' : 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    final tag = _getDisplayTag();
    final statusText = _getHumanStatusText();

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monogram Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: tag.length > 3 ? 11 : (tag.length > 2 ? 13 : 16),
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetInfo.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kPaper,
                            fontSize: 17,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      targetInfo.subtitle ?? targetInfo.id,
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        color: kMute,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(color: accentColor),
                const SizedBox(width: 7),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Primary Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isProbing ? null : onPingNow,
                  icon: isProbing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kInk,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isProbing ? 'Pinging...' : 'Ping Now',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPaper,
                    foregroundColor: kInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(40, 38),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onTraceRoute,
                icon: const Icon(Icons.alt_route_rounded, size: 15),
                label: const Text('Trace', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPaper,
                  side: const BorderSide(color: kLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(40, 38),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onToggleLive(!liveMonitor),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: liveMonitor
                        ? const Color(0x1A10B981)
                        : const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: liveMonitor
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : kLine,
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Auto',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          color: liveMonitor
                              ? const Color(0xFF10B981)
                              : kPaper,
                          fontSize: 11,
                          fontWeight: liveMonitor
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: liveMonitor,
                          onChanged: onToggleLive,
                          activeThumbColor: const Color(0xFF10B981),
                          activeTrackColor: const Color(0x4D10B981),
                          inactiveThumbColor: kMute,
                          inactiveTrackColor: const Color(0x28FFFFFF),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.targetInfo});

  final ItemProfileInfo targetInfo;

  @override
  Widget build(BuildContext context) {
    final whatItTests = targetInfo.whatItTests ??
        'Tests ping and response time to ${targetInfo.title}.';
    final whyItMatters = targetInfo.whyItMatters;

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF06B6D4),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'ABOUT THIS ITEM',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  color: kPaper,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            whatItTests,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kPaper.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.45,
                ),
          ),
          if (whyItMatters != null && whyItMatters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kLine),
              ),
              child: Text(
                whyItMatters,
                style: const TextStyle(
                  color: kMute,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = 1.0 + (_ctrl.value * 0.3);
        final opacity = 0.5 + (_ctrl.value * 0.5);
        return Container(
          width: 7 * scale,
          height: 7 * scale,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: 4 * scale,
                spreadRadius: 1 * scale,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiMetricGrid extends StatelessWidget {
  const _KpiMetricGrid({required this.metrics, required this.accentColor});

  final ItemMetrics metrics;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final avgStr = metrics.avgMs > 0 ? '${metrics.avgMs.toStringAsFixed(0)} ms' : '-';
    final uptimeStr = metrics.totalChecks > 0
        ? '${metrics.uptimePercent.toStringAsFixed(0)}%'
        : '-';
    final jitterStr = metrics.jitterMs > 0
        ? '± ${metrics.jitterMs.toStringAsFixed(1)} ms'
        : '± 0 ms';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: isWide ? 1.4 : 1.35,
          children: [
            _KpiCard(
              label: 'AVERAGE PING',
              value: avgStr,
              subtext: metrics.minMs > 0
                  ? 'Min ${metrics.minMs}ms · Max ${metrics.maxMs}ms'
                  : 'Recent average',
              icon: Icons.timer_outlined,
              accentColor: accentColor,
            ),
            _KpiCard(
              label: 'SUCCESS RATE',
              value: uptimeStr,
              subtext: '${metrics.okCount} of ${metrics.totalChecks} successful',
              icon: Icons.verified_outlined,
              accentColor: metrics.uptimePercent > 80
                  ? const Color(0xFF10B981)
                  : (metrics.uptimePercent > 40
                      ? const Color(0xFFF59E0B)
                      : kFail),
            ),
            _KpiCard(
              label: 'STABILITY',
              value: jitterStr,
              subtext: 'StdDev ±${metrics.stdDevMs.toStringAsFixed(1)}ms',
              icon: Icons.graphic_eq_rounded,
              accentColor: const Color(0xFF8B5CF6),
            ),
            _KpiCard(
              label: 'STATUS',
              value: metrics.isClean ? 'Working' : 'Error',
              subtext: metrics.filterStatus,
              icon: metrics.isClean
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              accentColor: metrics.isClean ? const Color(0xFF10B981) : kFail,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    color: kMute,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(icon, size: 15, color: accentColor),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kPaper,
            ),
          ),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              color: kSubtle,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.targetInfo,
    required this.engine,
    required this.phase,
    required this.metrics,
  });

  final ItemProfileInfo targetInfo;
  final ProbeEngine engine;
  final PhaseBreakdown? phase;
  final ItemMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DETAILS',
            style: TextStyle(
              fontFamily: 'Space Mono',
              color: kPaper,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _SpecRow(label: 'Address / Host', value: targetInfo.id),
          _SpecRow(label: 'Type', value: targetInfo.categoryLabel),
          if (targetInfo.provider != null)
            _SpecRow(label: 'Provider', value: targetInfo.provider!),
          _SpecRow(
            label: 'Port',
            value: '${targetInfo.port} (${targetInfo.category == ItemCategory.dns ? "UDP" : "TCP"})',
          ),
          _SpecRow(label: 'Network', value: engine.nic.label),
          if (phase?.resolvedIps != null && phase!.resolvedIps!.isNotEmpty)
            _SpecRow(
              label: 'Resolved IP',
              value: phase!.resolvedIps!.join(', '),
            ),
          _SpecRow(
            label: 'Result',
            value: metrics.filterStatus,
            isWarning: !metrics.isClean,
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: kMute,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Space Mono',
                color: isWarning ? kFail : kPaper,
                fontWeight: isWarning ? FontWeight.w600 : FontWeight.w400,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAuditLog extends StatelessWidget {
  const _RecentAuditLog({required this.samples, required this.accentColor});

  final List<ProbeSample> samples;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final recent = samples.reversed.take(8).toList();

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECENT PINGS',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  color: kPaper,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Last ${recent.length}',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  color: kMute,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'No pings recorded yet',
                  style: TextStyle(color: kMute, fontSize: 11),
                ),
              ),
            )
          else
            for (final s in recent) ...[
              _AuditItemRow(sample: s, accentColor: accentColor),
            ],
        ],
      ),
    );
  }
}

class _AuditItemRow extends StatelessWidget {
  const _AuditItemRow({required this.sample, required this.accentColor});

  final ProbeSample sample;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')}:${sample.timestamp.second.toString().padLeft(2, '0')}';
    final isOk = sample.status == HitStatus.ok;
    final statusColor = isOk ? accentColor : (sample.status == HitStatus.timeout ? const Color(0xFFF59E0B) : kFail);
    final statusLabel = isOk ? 'OK' : (sample.status == HitStatus.timeout ? 'TIMEOUT' : 'FAIL');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              color: kMute,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontFamily: 'Space Mono',
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sample.detail != null && sample.detail!.isNotEmpty
                  ? sample.detail!
                  : (isOk ? 'Success' : 'Error'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: kPaper,
              ),
            ),
          ),
          Text(
            sample.ms != null ? '${sample.ms}ms' : '-',
            style: TextStyle(
              fontFamily: 'Space Mono',
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
