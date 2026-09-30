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
    this.privacyMode = false,
  });
  final String target;
  final String? title;
  final bool autoStart, privacyMode;
  static void open(
    BuildContext context, {
    required String target,
    String? title,
    bool autoStart = true,
    bool privacyMode = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteMapPage(
          target: target,
          title: title,
          autoStart: autoStart,
          privacyMode: privacyMode,
        ),
      ),
    );
  }

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  StreamSubscription<TracerouteResult>? _subscription;
  TracerouteResult? _result;
  bool _running = false;
  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _result = null;
      _running = true;
    });
    _subscription = TracerouteEngine.instance
        .trace(widget.target)
        .listen(
          (r) {
            if (mounted) {
              setState(() {
                _result = r;
                _running = !r.isComplete;
              });
            }
          },
          onError: (Object _) {
            if (mounted) setState(() => _running = false);
          },
        );
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _copy() async {
    final report = StringBuffer(
      'NetChecker route trace\n${widget.privacyMode ? 'Target hidden' : widget.target}\n',
    );
    for (final hop in _result?.hops ?? <TracerouteHop>[]) {
      report.writeln(
        '${hop.ttl}. ${widget.privacyMode ? 'Address hidden' : hop.displayHost} · ${hop.rttMs == null ? 'No response' : '${hop.rttMs} ms'}',
      );
    }
    await Clipboard.setData(ClipboardData(text: report.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route report copied')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Route trace')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.privacyMode
                ? 'Target hidden'
                : widget.title ?? widget.target,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Measured hops from the system route command. Routers may ignore probes even when traffic passes through. Missing replies do not establish packet loss for your applications. This command uses system routing, not the monitor’s adapter binding.',
            style: TextStyle(color: kMute),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _running ? _stop : _start,
                icon: Icon(
                  _running ? Icons.stop : Icons.route_outlined,
                  size: 18,
                ),
                label: Text(_running ? 'Stop trace' : 'Trace again'),
              ),
              OutlinedButton.icon(
                onPressed: _result?.hops.isNotEmpty == true ? _copy : null,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy route'),
              ),
            ],
          ),
          if (_result?.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_result!.error!, style: const TextStyle(color: kTo)),
            ),
          if (_running)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Tracing… hops appear as the system measures them.',
                style: TextStyle(color: kMute),
              ),
            ),
          const SizedBox(height: 20),
          for (final hop in _result?.hops ?? <TracerouteHop>[])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kLine)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${hop.ttl}',
                      style: mono.copyWith(color: kMute),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.privacyMode ? 'Hop ${hop.ttl}' : hop.displayHost,
                      style: mono,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hop.rttMs == null ? 'No reply' : '${hop.rttMs} ms',
                    style: mono.copyWith(color: statusColor(hop.status)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
