import 'dart:convert';
import '../probe/engine.dart';
import '../probe/models.dart';

enum ExportFormat { markdown, csv, json, plaintext }

class ReportExport {
  static String generate(
    ProbeEngine engine, {
    ExportFormat format = ExportFormat.markdown,
    bool redact = true,
  }) {
    final items = <Map<String, dynamic>>[];
    final groups = <String, Map<String, dynamic>>{
      for (final name in ['domains', 'dns', 'edges', 'proto', 'hunt']) name: {},
    };
    for (var i = 0; i < engine.targets.length; i++) {
      final target = engine.targets[i],
          hit = engine.hitFor(target.key),
          metric = engine.metricsFor(target.key),
          counter = engine.counterFor(target.key);
      final id = redact
          ? 'target_${(i + 1).toString().padLeft(3, '0')}'
          : target.key.value;
      Map<String, dynamic>? phase(PhaseBreakdown? p) => p == null
          ? null
          : {
              'dnsMs': p.dnsMs,
              'tcpMs': p.tcpMs,
              'tlsMs': p.tlsMs,
              'httpMs': p.httpMs,
              'httpStatusCode': p.httpStatusCode,
              'dnsResponseCode': p.dnsResponseCode,
              'certificateVerified': p.certificateVerified,
              'method': p.method,
              'resolvedIps': redact && p.resolvedIps?.isNotEmpty == true
                  ? ['[redacted]']
                  : p.resolvedIps,
            };
      final row = <String, dynamic>{
        'id': id,
        'title': redact ? 'Target ${i + 1}' : target.title,
        'category': target.category.name,
        'address': redact ? '[redacted]' : target.address,
        'query': redact && target.key.query.isNotEmpty
            ? '[redacted]'
            : target.key.query,
        'enabled': engine.enabled(target.key),
        'status': hit.status.name,
        'detail': hit.detail,
        'warning': hit.warning,
        'latencyMs': hit.ms,
        'checkedAt': hit.at?.toIso8601String(),
        'completedChecks': counter.completed,
        'successfulChecks': counter.successful,
        'successPercent': counter.successRate,
        'recentSampleCount': metric.totalChecks,
        'avgMs': metric.totalChecks == 0 ? null : metric.avgMs,
        'minMs': metric.okCount == 0 ? null : metric.minMs,
        'maxMs': metric.okCount == 0 ? null : metric.maxMs,
        'stdDevMs': metric.okCount == 0 ? null : metric.stdDevMs,
        'phase': phase(hit.phase),
        'samples': engine
            .historyFor(target.key)
            .map(
              (s) => {
                'timestamp': s.timestamp.toIso8601String(),
                'status': s.status.name,
                'ms': s.ms,
                'detail': s.detail,
                'warning': s.warning,
                'phase': phase(s.phase),
              },
            )
            .toList(),
      };
      items.add(row);
      final group = switch (target.category) {
        ItemCategory.domain => 'domains',
        ItemCategory.dns => 'dns',
        ItemCategory.edge => 'edges',
        ItemCategory.proto => 'proto',
        ItemCategory.hunt => 'hunt',
      };
      groups[group]![id] = row;
    }
    final context = redact
        ? 'Context ${engine.contextNumber} · adapter redacted'
        : engine.contextLabel;
    if (format == ExportFormat.json) {
      return const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 2,
        'app': 'NetChecker',
        'generatedAt': engine.clock.now().toIso8601String(),
        'redacted': redact,
        'context': context,
        'running': engine.isRunning,
        'retention':
            'Current session only; recent history is bounded to ${ProbeEngine.historyLimit} observations per target.',
        ...groups,
      });
    }
    final headers = [
      'Target',
      'Category',
      'Enabled',
      'Status',
      'Detail',
      'Latency ms',
      'Completed checks',
      'Successful checks',
      'Success %',
    ];
    List<String> cells(Map<String, dynamic> r) => [
      r['title'],
      r['category'],
      '${r['enabled']}',
      r['status'],
      r['detail'] ?? '',
      r['latencyMs']?.toString() ?? '',
      '${r['completedChecks']}',
      '${r['successfulChecks']}',
      (r['successPercent'] as double?)?.toStringAsFixed(1) ?? '',
    ];
    if (format == ExportFormat.csv) {
      return '${[headers, ...items.map(cells)].map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n';
    }
    final out = StringBuffer(
      'NetChecker report\n$context\nGenerated ${engine.clock.now().toIso8601String()}\n${redact ? 'Identifiers redacted' : 'Includes target and adapter identifiers'}\n\n',
    );
    if (format == ExportFormat.markdown) {
      out.writeln('| ${headers.join(' | ')} |');
      out.writeln('| ${headers.map((_) => '---').join(' | ')} |');
      for (final item in items) {
        out.writeln('| ${cells(item).map(markdownCell).join(' | ')} |');
      }
    } else {
      for (final item in items) {
        out.writeln(cells(item).join(' · '));
      }
    }
    out.writeln(
      '\nSuccess rate counts completed application checks, not packet loss or time-based uptime.',
    );
    out.writeln(
      'DNS response checks can succeed even when the resolver returns a lookup error.',
    );
    return out.toString();
  }

  static String csvCell(String input) {
    final safe = RegExp(r'^[=+@\-\t\r\n]').hasMatch(input.trimLeft())
        ? "'$input"
        : input;
    return '"${safe.replaceAll('"', '""')}"';
  }

  static String markdownCell(String input) => input
      .replaceAll('\\', '\\\\')
      .replaceAll('|', '\\|')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
