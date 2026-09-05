import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/update_service.dart';
import '../probe/engine.dart';
import '../probe/models.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'desk_window.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({
    super.key,
    required this.engine,
    this.showWindowControls = false,
  });

  final ProbeEngine engine;
  final bool showWindowControls;

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  late final TextEditingController _hunt;
  late final TextEditingController _extra;
  late AppSettings _draft;

  String _appVersion = '1.0.0+1';
  bool _checkingUpdate = false;
  UpdateCheckResult? _updateResult;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String? _downloadStatusText;

  @override
  void initState() {
    super.initState();
    _draft = widget.engine.settings;
    _hunt = TextEditingController(text: _draft.huntName);
    _extra = TextEditingController(text: _draft.extraDomains.join('\n'));
    _initVersion();
  }

  Future<void> _initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.buildNumber.isNotEmpty
              ? '${info.version}+${info.buildNumber}'
              : info.version;
        });
      }
    } catch (_) {
      // Keep default fallback
    }
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateResult = null;
      _downloadStatusText = null;
    });

    try {
      final res = await UpdateService.checkForUpdates(
        currentVersionOverride: _appVersion,
      );
      if (mounted) {
        setState(() {
          _updateResult = res;
          _checkingUpdate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
          _updateResult = UpdateCheckResult(
            currentVersion: _appVersion,
            isUpdateAvailable: false,
            errorMessage: 'Error: $e',
          );
        });
      }
    }
  }

  Future<void> _downloadAndInstall(ReleaseInfo release) async {
    final apk = release.apkAsset;
    if (apk == null) {
      await UpdateService.openUrl(release.htmlUrl);
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Starting download...';
    });

    try {
      final file = await UpdateService.downloadApk(
        downloadUrl: apk.downloadUrl,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _downloadProgress = received / total;
              final mbRec = (received / (1024 * 1024)).toStringAsFixed(1);
              final mbTot = (total / (1024 * 1024)).toStringAsFixed(1);
              _downloadStatusText = '$mbRec MB / $mbTot MB (${(_downloadProgress * 100).toInt()}%)';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadStatusText = 'Download completed. Launching installer...';
        });
      }

      await UpdateService.installApk(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadStatusText = 'Download failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _hunt.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final extra = _extra.text
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await widget.engine.apply(
      _draft.copyWith(
        huntName: _hunt.text.trim().isEmpty ? 'youtube.com' : _hunt.text.trim(),
        extraDomains: extra,
      ),
    );
    if (widget.showWindowControls) {
      await DeskWindow.setAlwaysOnTop(_draft.alwaysOnTop);
      await DeskWindow.setCompact(_draft.alwaysOnTop);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final nics = widget.engine.nics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Targets & Hunting Section
        _SectionCard(
          icon: Icons.radar_rounded,
          title: 'Targeting & DNS Hunt',
          description: 'Configure DNS hunter query target and website catalog',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _hunt,
                decoration: InputDecoration(
                  labelText: 'DNS Hunt Target Host',
                  hintText: 'e.g. youtube.com',
                  prefixIcon: const Icon(Icons.travel_explore_rounded, size: 16),
                  helperText: 'Domain resolved by all DNS servers to detect poisoning',
                  helperStyle: TextStyle(color: kMute.withValues(alpha: 0.7), fontSize: 10),
                ),
              ),
              const SizedBox(height: 14),
              _SwitchCard(
                title: 'Default Top 30 Domains',
                subtitle: 'Include high-traffic websites commonly filtered in Iran',
                value: _draft.useDefaultDomains,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(useDefaultDomains: v);
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _extra,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'Space Mono', fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Custom Target Domains',
                  hintText: 'example.com\ncloudflare.com',
                  helperText: 'One host or domain per line',
                  helperStyle: TextStyle(color: kMute.withValues(alpha: 0.7), fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Probe Timing Section
        _SectionCard(
          icon: Icons.timer_outlined,
          title: 'Probe Timers & Network',
          description: 'Request timeouts and delay intervals between probes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MsSlider(
                label: 'HTTP timeout',
                value: _draft.httpTimeoutMs,
                min: 500,
                max: 15000,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(httpTimeoutMs: v);
                }),
              ),
              const SizedBox(height: 8),
              _MsSlider(
                label: 'Delay Between Site Probes',
                value: _draft.itemDelayMs,
                min: 0,
                max: 5000,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(itemDelayMs: v);
                }),
              ),
              const SizedBox(height: 8),
              _MsSlider(
                label: 'DNS Query Timeout',
                value: _draft.dnsTimeoutMs,
                min: 300,
                max: 8000,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(dnsTimeoutMs: v);
                }),
              ),
              const SizedBox(height: 8),
              _MsSlider(
                label: 'Delay Between DNS Probes',
                value: _draft.dnsDelayMs,
                min: 0,
                max: 5000,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(dnsDelayMs: v);
                }),
              ),
              if (widget.showWindowControls && nics.length > 1) ...[
                const SizedBox(height: 14),
                Text(
                  'Network Interface',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kPaper,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      value: nics.any((n) => n.id == _draft.nicId)
                          ? _draft.nicId
                          : NicChoice.any.id,
                      dropdownColor: const Color(0xFF1A1A20),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: kMute),
                      items: [
                        for (final n in nics)
                          DropdownMenuItem(
                            value: n.id,
                            child: Row(
                              children: [
                                const Icon(Icons.lan_outlined, size: 15, color: kMute),
                                const SizedBox(width: 8),
                                Text(
                                  n.label,
                                  style: const TextStyle(fontSize: 12.5, color: kPaper),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() => _draft = _draft.copyWith(nicId: id));
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Interface & Privacy Section
        _SectionCard(
          icon: Icons.shield_outlined,
          title: 'Display & Privacy',
          description: 'Telemetry privacy masking and report formats',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchCard(
                title: 'Privacy Mode',
                subtitle: 'Mask hostnames and IPs on the homescreen grid',
                value: _draft.privacyMode,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(privacyMode: v);
                }),
              ),
              if (widget.showWindowControls) ...[
                const SizedBox(height: 12),
                _SwitchCard(
                  title: 'Always on Top',
                  subtitle: 'Keep a compact corner instrument visible while testing',
                  value: _draft.alwaysOnTop,
                  onChanged: (v) => setState(() {
                    _draft = _draft.copyWith(alwaysOnTop: v);
                  }),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Report Export Format',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kPaper,
                    ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    value: _draft.exportFormat,
                    dropdownColor: const Color(0xFF1A1A20),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: kMute),
                    items: const [
                      DropdownMenuItem(
                        value: 'markdown',
                        child: Text('Markdown Table (.md)', style: TextStyle(fontSize: 12.5, color: kPaper)),
                      ),
                      DropdownMenuItem(
                        value: 'csv',
                        child: Text('CSV Spreadsheet (.csv)', style: TextStyle(fontSize: 12.5, color: kPaper)),
                      ),
                      DropdownMenuItem(
                        value: 'json',
                        child: Text('JSON Machine-Readable (.json)', style: TextStyle(fontSize: 12.5, color: kPaper)),
                      ),
                      DropdownMenuItem(
                        value: 'plaintext',
                        child: Text('Plaintext Summary (.txt)', style: TextStyle(fontSize: 12.5, color: kPaper)),
                      ),
                    ],
                    onChanged: (fmt) {
                      if (fmt == null) return;
                      setState(() => _draft = _draft.copyWith(exportFormat: fmt));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Updates & Maintenance Section
        _SectionCard(
          icon: Icons.system_update_alt_rounded,
          title: 'Updates',
          description: 'Version management and telemetry reset',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NetChecker',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: kPaper,
                        ),
                      ),
                      Text(
                        'Version v$_appVersion',
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 11,
                          color: kMute,
                        ),
                      ),
                    ],
                  ),
                  _buildUpdateStatusCard(context),
                ],
              ),
              const SizedBox(height: 12),
              _SwitchCard(
                title: 'Auto-Check for Updates',
                subtitle: 'Automatically check GitHub releases on startup',
                value: _draft.autoCheckUpdates,
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(autoCheckUpdates: v);
                }),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  widget.engine.resetAllStats();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All statistics and telemetry reset')),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Statistics'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kFail,
                  side: BorderSide(color: kFail.withValues(alpha: 0.3)),
                  backgroundColor: kFail.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(48, 40),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. Apply Button
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Apply Changes'),
          style: FilledButton.styleFrom(
            backgroundColor: kPaper,
            foregroundColor: kInk,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateStatusCard(BuildContext context) {
    final isAndroid = !kIsWeb && Platform.isAndroid;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_checkingUpdate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: kPaper),
            ),
            SizedBox(width: 10),
            Text(
              'Checking releases...',
              style: TextStyle(fontSize: 11, color: kPaper),
            ),
          ],
        ),
      );
    }

    if (_updateResult != null) {
      final res = _updateResult!;
      if (res.isUpdateAvailable && res.latestRelease != null) {
        final rel = res.latestRelease!;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            border: Border.all(color: kOk.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.new_releases_outlined, size: 16, color: kOk),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'New: ${rel.tagName}',
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: kOk,
                      ),
                    ),
                  ),
                ],
              ),
              if (rel.name.isNotEmpty && rel.name != rel.tagName) ...[
                const SizedBox(height: 4),
                Text(
                  rel.name,
                  style: const TextStyle(fontSize: 11, color: kPaper),
                ),
              ],
              if (rel.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 80),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      rel.body.trim(),
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9.5,
                        color: kMute,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (_downloading) ...[
                LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: kOk,
                  backgroundColor: colorScheme.outlineVariant,
                ),
                const SizedBox(height: 4),
                if (_downloadStatusText != null)
                  Text(
                    _downloadStatusText!,
                    style: const TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10,
                      color: kPaper,
                    ),
                  ),
              ] else ...[
                if (_downloadStatusText != null) ...[
                  Text(
                    _downloadStatusText!,
                    style: const TextStyle(fontSize: 11, color: kMute),
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isAndroid && rel.apkAsset != null)
                      FilledButton.icon(
                        onPressed: () => _downloadAndInstall(rel),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Install APK'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kOk,
                          foregroundColor: kInk,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(36, 34),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => UpdateService.openUrl(rel.htmlUrl),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('GitHub'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(36, 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      } else if (res.errorMessage != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            border: Border.all(color: kFail.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 14, color: kFail),
              const SizedBox(width: 6),
              Text(
                'Update check failed',
                style: const TextStyle(fontSize: 11, color: kMute),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 13),
                onPressed: _checkUpdate,
                tooltip: 'Retry',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: kOk),
              const SizedBox(width: 6),
              const Text(
                'Up to date',
                style: TextStyle(fontSize: 11, color: kPaper),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _checkUpdate,
                child: const Text(
                  'Check',
                  style: TextStyle(fontSize: 10.5, color: kMute, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        );
      }
    }

    return OutlinedButton.icon(
      onPressed: _checkUpdate,
      icon: const Icon(Icons.sync, size: 14),
      label: const Text('Check for Updates'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(40, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Icon(icon, size: 16, color: kPaper),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: kPaper,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: kMute,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: kPaper,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kMute,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MsSlider extends StatelessWidget {
  const _MsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: kPaper),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                '${value}ms',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: kPaper,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: ((max - min) / 100).round().clamp(1, 200),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
