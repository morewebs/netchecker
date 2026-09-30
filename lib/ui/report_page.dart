import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../export/report_export.dart';
import '../probe/engine.dart';
import '../theme.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.engine});
  final ProbeEngine engine;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late ExportFormat _format;
  bool _redact = true;
  late String _report;
  @override
  void initState() {
    super.initState();
    _format = ExportFormat.values.firstWhere(
      (v) => v.name == widget.engine.settings.exportFormat,
      orElse: () => ExportFormat.markdown,
    );
    _generate();
  }

  void _generate() {
    _report = ReportExport.generate(
      widget.engine,
      format: _format,
      redact: _redact,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export report')),
    body: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Preview a snapshot of this session. Refresh to include newer checks.',
                  style: TextStyle(color: kMute),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownMenu<ExportFormat>(
                      label: const Text('Format'),
                      initialSelection: _format,
                      dropdownMenuEntries: ExportFormat.values
                          .map(
                            (f) => DropdownMenuEntry(
                              value: f,
                              label: f.name.toUpperCase(),
                            ),
                          )
                          .toList(),
                      onSelected: (f) {
                        if (f != null) {
                          setState(() {
                            _format = f;
                            _generate();
                          });
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(_generate),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh snapshot'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _report));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy report'),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Redact target and adapter identifiers'),
                  subtitle: Text(
                    widget.engine.settings.privacyMode
                        ? 'Privacy mode keeps redaction on.'
                        : 'Turn off only when you want to include hostnames and addresses.',
                  ),
                  value: _redact,
                  onChanged: widget.engine.settings.privacyMode
                      ? null
                      : (v) => setState(() {
                          _redact = v;
                          _generate();
                        }),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(_report, style: mono.copyWith(fontSize: 11)),
          ),
        ],
      ),
    ),
  );
}
