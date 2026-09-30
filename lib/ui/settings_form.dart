import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/update_service.dart';
import '../probe/engine.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'desk_window.dart';
import 'presentation.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.engine,
    required this.desktop,
    this.initialUpdate,
  });
  final ProbeEngine engine;
  final bool desktop;
  final UpdateCheckResult? initialUpdate;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SettingsForm(
            engine: engine,
            showWindowControls: desktop,
            initialUpdate: initialUpdate,
          ),
        ),
      ),
    ),
  );
}

class SettingsForm extends StatefulWidget {
  const SettingsForm({
    super.key,
    required this.engine,
    this.showWindowControls = false,
    this.initialUpdate,
  });
  final ProbeEngine engine;
  final bool showWindowControls;
  final UpdateCheckResult? initialUpdate;
  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final _form = GlobalKey<FormState>();
  late AppSettings _draft;
  late TextEditingController _extra, _hunt;
  bool _saving = false, _checking = false;
  String _version = '';
  UpdateCheckResult? _update;
  @override
  void initState() {
    super.initState();
    _draft = widget.engine.settings;
    _extra = TextEditingController(text: _draft.extraDomains.join('\n'));
    _hunt = TextEditingController(text: _draft.huntName);
    _update = widget.initialUpdate;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  @override
  void dispose() {
    _extra.dispose();
    _hunt.dispose();
    super.dispose();
  }

  List<String> _entries() =>
      _extra.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
  String? _validateTargets(String? _) {
    try {
      for (final entry in _entries()) {
        parseWebsite(entry);
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'Check the hostnames and ports.';
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final next = _draft.copyWith(
        extraDomains: _entries()
            .map((s) => parseWebsite(s).toString())
            .toSet()
            .toList(),
        huntName: parseDnsName(_hunt.text),
      );
      await widget.engine.apply(next);
      if (widget.showWindowControls) {
        await DeskWindow.setAlwaysOnTop(next.alwaysOnTop);
        await DeskWindow.setCompact(next.compactMode);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final result = await UpdateService.checkForUpdates();
    if (mounted) {
      setState(() {
        _update = result;
        _checking = false;
      });
    }
  }

  Future<void> _download() async {
    final release = _update?.latestRelease;
    if (release == null) return;
    final asset = Platform.isWindows
        ? release.windowsAsset
        : Platform.isLinux
        ? release.linuxAsset
        : release.apkAsset;
    final opened = await UpdateService.openUrl(
      asset?.downloadUrl ?? release.htmlUrl,
    );
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the download. Try the release page in your browser.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              const SectionLabel('Monitoring'),
              const Text(
                'Checks run continuously while the app is active. Each lane checks one target at a time.',
                style: TextStyle(color: kMute),
              ),
              _Timing(
                label: 'Website timeout',
                value: _draft.httpTimeoutMs,
                min: 500,
                max: 15000,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(httpTimeoutMs: v)),
              ),
              _Timing(
                label: 'Delay between website checks',
                value: _draft.itemDelayMs,
                min: 0,
                max: 5000,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(itemDelayMs: v)),
              ),
              _Timing(
                label: 'DNS timeout',
                value: _draft.dnsTimeoutMs,
                min: 300,
                max: 8000,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(dnsTimeoutMs: v)),
              ),
              _Timing(
                label: 'Delay between DNS checks',
                value: _draft.dnsDelayMs,
                min: 0,
                max: 5000,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(dnsDelayMs: v)),
              ),
              if (widget.showWindowControls) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.engine.nics.any((n) => n.id == _draft.nicId)
                      ? _draft.nicId
                      : 'missing',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Network adapter',
                  ),
                  items: [
                    for (final nic in widget.engine.nics)
                      DropdownMenuItem(
                        value: nic.id,
                        child: Text(
                          _draft.privacyMode && nic.id != 'any'
                              ? 'Adapter ${widget.engine.nics.indexOf(nic)}'
                              : nic.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (!widget.engine.nics.any((n) => n.id == _draft.nicId))
                      const DropdownMenuItem(
                        value: 'missing',
                        enabled: false,
                        child: Text('Selected adapter unavailable'),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null && id != 'missing') {
                      setState(() => _draft = _draft.copyWith(nicId: id));
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Binds probe sockets to an adapter. Website hostname resolution still uses system DNS. A missing selected adapter pauses checks.',
                  style: TextStyle(color: kMute, fontSize: 12),
                ),
              ],
              const SectionLabel('Targets'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include the default websites'),
                subtitle: const Text(
                  '30 popular destinations, including sites commonly filtered in restricted networks.',
                ),
                value: _draft.useDefaultDomains,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(useDefaultDomains: v),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extra,
                minLines: 3,
                maxLines: 6,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateTargets,
                decoration: const InputDecoration(
                  labelText: 'Custom websites',
                  hintText: 'example.com\nhttps://example.com/status',
                  helperText:
                      'One hostname, IP or HTTPS URL per line. Duplicates are merged.',
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _hunt,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  try {
                    parseDnsName(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Enter a valid hostname for DNS comparison.';
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'DNS comparison hostname',
                  helperText:
                      'Compare the answers returned by different resolvers.',
                  helperMaxLines: 2,
                ),
              ),
              const SectionLabel('Appearance'),
              const Text(
                'Dark surfaces with clear labels and tabular measurements. System text size and reduced motion are respected.',
                style: TextStyle(color: kMute),
              ),
              if (widget.showWindowControls) ...[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Always on top'),
                  subtitle: const Text(
                    'Keep the window above other apps without resizing it.',
                  ),
                  value: _draft.alwaysOnTop,
                  onChanged: (v) =>
                      setState(() => _draft = _draft.copyWith(alwaysOnTop: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compact mode'),
                  subtitle: const Text(
                    'A small monitoring window. Leaving restores its previous bounds.',
                  ),
                  value: _draft.compactMode,
                  onChanged: (v) =>
                      setState(() => _draft = _draft.copyWith(compactMode: v)),
                ),
              ],
              const SectionLabel('Privacy'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide target and adapter identifiers'),
                subtitle: const Text(
                  'Masks the monitor, target details, route output and reports.',
                ),
                value: _draft.privacyMode,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(privacyMode: v)),
              ),
              const Text(
                'Results stay in memory until you close NetChecker. There are no accounts or analytics. Checks contact the selected destinations; update checks contact GitHub.',
                style: TextStyle(color: kMute),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _draft.exportFormat,
                decoration: const InputDecoration(
                  labelText: 'Default report format',
                ),
                items: ['markdown', 'csv', 'json', 'plaintext']
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _draft = _draft.copyWith(exportFormat: v));
                  }
                },
              ),
              const SectionLabel('Updates'),
              Text(
                'NetChecker${_version.isEmpty ? '' : ' $_version'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Check for updates on startup'),
                subtitle: const Text(
                  'Checks once per launch without interrupting monitoring.',
                ),
                value: _draft.autoCheckUpdates,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(autoCheckUpdates: v),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(_checking ? 'Checking…' : 'Check for updates'),
                  ),
                  if (_update?.isUpdateAvailable == true)
                    FilledButton.icon(
                      onPressed: _download,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open download'),
                    ),
                ],
              ),
              if (_update != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _update!.errorMessage ??
                        (_update!.isUpdateAvailable
                            ? 'Version ${_update!.latestRelease!.tagName} is available. Downloads open in your browser.'
                            : 'You are up to date.'),
                    style: const TextStyle(color: kMute),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: kCard,
            border: Border(top: BorderSide(color: kLine)),
          ),
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, bounds) {
              const explanation = Text(
                'Monitoring changes begin a new context.',
                style: TextStyle(color: kMute, fontSize: 12),
              );
              final apply = FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Apply changes'),
              );
              if (bounds.maxWidth < 520 ||
                  MediaQuery.textScalerOf(context).scale(14) >= 23) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [explanation, const SizedBox(height: 12), apply],
                );
              }
              return Row(
                children: [
                  const Expanded(child: explanation),
                  const SizedBox(width: 12),
                  apply,
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _Timing extends StatelessWidget {
  const _Timing({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Text('${value}ms', style: mono),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 100,
          label: '$value milliseconds',
          semanticFormatterCallback: (v) => '${v.round()} milliseconds',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    ),
  );
}
