import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../probe/models.dart';
import '../../probe/traceroute.dart';
import '../../theme.dart';

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({
    super.key,
    required this.target,
    this.title,
    this.autoStart = true,
  });

  final String target;
  final String? title;
  final bool autoStart;

  static void open(BuildContext context, {required String target, String? title, bool autoStart = true}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteMapPage(target: target, title: title, autoStart: autoStart),
      ),
    );
  }

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  StreamSubscription<TracerouteResult>? _sub;
  TracerouteResult? _result;
  bool _isTracing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _startTrace();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startTrace() {
    _sub?.cancel();
    setState(() {
      _isTracing = true;
      _result = null;
    });

    _sub = TracerouteEngine.instance.trace(widget.target).listen(
      (res) {
        if (mounted) {
          setState(() {
            _result = res;
            _isTracing = !res.isComplete;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isTracing = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isTracing = false;
          });
        }
      },
    );
  }

  void _copyTraceReport() {
    if (_result == null) return;
    final sb = StringBuffer();
    sb.writeln('Traceroute to ${widget.target} (${_result!.hops.length} hops):');
    for (final h in _result!.hops) {
      final host = h.displayHost;
      final ms = h.rttMs != null ? '${h.rttMs}ms' : '*';
      final asn = h.asn != null ? ' [${h.asn!.label}]' : '';
      final geo = h.geo != null ? ' (${h.geo!.locationString})' : '';
      sb.writeln('${h.ttl.toString().padLeft(2)}. $host - $ms$asn$geo');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route report copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hops = _result?.hops ?? [];
    final isComplete = _result?.isComplete ?? false;

    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kPaper, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ROUTE MAP · TRACEROUTE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kMute,
                    letterSpacing: 0.8,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              widget.title ?? widget.target,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: kPaper,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: kPaper, size: 16),
            tooltip: 'Copy Route (C)',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: hops.isNotEmpty ? _copyTraceReport : null,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              _isTracing ? Icons.stop_rounded : Icons.refresh_rounded,
              color: _isTracing ? kFail : kOk,
              size: 18,
            ),
            tooltip: _isTracing ? 'Stop Trace' : 'Retrace (R)',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: () {
              if (_isTracing) {
                _sub?.cancel();
                setState(() => _isTracing = false);
              } else {
                _startTrace();
              }
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          // Status Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF121215),
              border: Border(bottom: BorderSide(color: kLine, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isTracing ? kTo : (isComplete ? kOk : kMute),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isTracing ? kTo : (isComplete ? kOk : kMute)).withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isTracing ? 'Discovering network hops...' : (isComplete ? 'Trace Complete' : 'Tracing Route'),
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 11,
                        color: kPaper,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${hops.length} hops discovered',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11,
                    color: kMute,
                  ),
                ),
              ],
            ),
          ),

          // Hop List
          Expanded(
            child: hops.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kOk,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tracing route to ${widget.target}...',
                          style: const TextStyle(color: kMute, fontSize: 11.5),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: hops.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final hop = hops[index];
                      return _HopTile(hop: hop, isLast: index == hops.length - 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HopTile extends StatelessWidget {
  const _HopTile({
    required this.hop,
    required this.isLast,
  });

  final TracerouteHop hop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final hasResp = hop.hasResponse;
    final rtt = hop.rttMs;
    Color statusColor = kOk;
    if (!hasResp || hop.status == HitStatus.timeout) {
      statusColor = kTo;
    } else if (rtt != null && rtt > 150) {
      statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kLine, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // TTL Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kLine),
                ),
                child: Text(
                  '#${hop.ttl}',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: kPaper,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Country Flag
              if (hop.geo != null) ...[
                Text(
                  hop.geo!.flagEmoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
              ],

              // Host / IP
              Expanded(
                child: Text(
                  hop.displayHost,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: hasResp ? kPaper : kMute,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Latency Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rtt != null ? '${rtt}ms' : (hop.lossPercent >= 100 ? 'Timed out' : '* * *'),
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Metadata Sub-row
          if (hop.ip != null || hop.asn != null || hop.geo != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (hop.ip != null && hop.hostname != null && hop.ip != hop.hostname)
                  _MetaChip(label: hop.ip!),
                if (hop.asn != null)
                  _MetaChip(label: hop.asn!.label, color: const Color(0xFF8B5CF6)),
                if (hop.geo != null && hop.geo!.locationString != 'Unknown Location')
                  _MetaChip(label: hop.geo!.locationString, color: const Color(0xFF06B6D4)),
                if (hop.lossPercent > 0)
                  _MetaChip(
                    label: '${hop.lossPercent.round()}% loss',
                    color: kFail,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.color = kMute,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 9,
          color: color == kMute ? kPaper : color,
        ),
      ),
    );
  }
}
