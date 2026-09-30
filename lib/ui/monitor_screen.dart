import 'dart:async';
import 'package:flutter/material.dart';
import '../data/update_service.dart';
import '../probe/engine.dart';
import '../probe/models.dart';
import '../theme.dart';
import 'desk_window.dart';
import 'keyboard/shortcuts.dart';
import 'keyboard/shortcuts_dialog.dart';
import 'presentation.dart';
import 'profile/item_profile_page.dart';
import 'report_page.dart';
import 'session_page.dart';
import 'settings_form.dart';
import 'strings.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, required this.engine, required this.desktop});
  final ProbeEngine engine;
  final bool desktop;
  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _search = TextEditingController();
  int _view = 0;
  String _filter = 'All results';
  bool _favorites = false, _updateChecked = false;
  ProbeKey? _selected;
  UpdateCheckResult? _update;
  ProbeEngine get engine => widget.engine;
  @override
  void initState() {
    super.initState();
    engine.addListener(_onEngine);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEngine());
  }

  void _onEngine() {
    if (!_updateChecked && engine.targets.isNotEmpty) {
      _updateChecked = true;
      if (engine.settings.autoCheckUpdates) unawaited(_checkUpdate());
    }
  }

  Future<void> _checkUpdate() async {
    final update = await UpdateService.checkForUpdates();
    if (mounted) setState(() => _update = update);
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    _search.dispose();
    super.dispose();
  }

  void _settings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        engine: engine,
        desktop: widget.desktop,
        initialUpdate: _update,
      ),
    ),
  );
  void _report() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ReportPage(engine: engine)));
  void _session() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SessionPage(engine: engine)));
  Future<void> _pin() async {
    final on = !engine.settings.alwaysOnTop;
    await engine.setAlwaysOnTop(on);
    final applied = await DeskWindow.setAlwaysOnTop(on);
    if (mounted && !applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This window manager does not support always-on-top.'),
        ),
      );
    }
  }

  Future<void> _compact() async {
    final on = !engine.settings.compactMode;
    await engine.setCompact(on);
    await DeskWindow.setCompact(on);
  }

  List<ProbeTarget> _group(int view) => engine.targets
      .where(
        (t) => view == 0
            ? t.category == ItemCategory.domain
            : view == 1
            ? t.category == ItemCategory.dns || t.category == ItemCategory.hunt
            : t.category == ItemCategory.proto ||
                  t.category == ItemCategory.edge,
      )
      .toList();

  Widget _largeTextMonitor(List<ProbeTarget> targets) => CustomScrollView(
    key: PageStorageKey('accessible-monitor-$_view'),
    slivers: [
      SliverAppBar(
        pinned: true,
        automaticallyImplyLeading: false,
        title: FilledButton.icon(
          onPressed: () => engine.setRunning(!engine.isRunning),
          icon: Icon(
            engine.isRunning ? Icons.pause : Icons.play_arrow,
            size: 18,
          ),
          label: Text(engine.isRunning ? AppStrings.pause : AppStrings.resume),
        ),
        actions: [_actions()],
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.monitor,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(engine.runLabel, style: const TextStyle(color: kMute)),
              Text(
                contextName(engine),
                style: const TextStyle(color: kMute, fontSize: 12),
              ),
              Freshness(at: engine.latestAt, prefix: 'Last result · '),
              if (engine.persistenceError != null)
                Text(engine.persistenceError!),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      SizedBox(
                        width: 184,
                        child: _ViewTab(
                          title: [
                            AppStrings.websites,
                            AppStrings.dns,
                            AppStrings.advanced,
                          ][i],
                          selected: i == _view,
                          count: _group(i)
                              .where(
                                (t) =>
                                    engine.enabled(t.key) &&
                                    engine.hitFor(t.key).status == HitStatus.ok,
                              )
                              .length,
                          total: _group(
                            i,
                          ).where((t) => engine.enabled(t.key)).length,
                          onTap: () => setState(() => _view = i),
                          compact: false,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search targets',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Filter results',
                    onSelected: (v) => setState(() => _filter = v),
                    itemBuilder: (_) =>
                        [
                              'All results',
                              'Needs attention',
                              'Responding',
                              'Not checked',
                              'Disabled',
                            ]
                            .map((v) => PopupMenuItem(value: v, child: Text(v)))
                            .toList(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _filter,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.expand_more, size: 16),
                        ],
                      ),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: _favorites,
                    onSelected: (v) => setState(() => _favorites = v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (targets.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyResults(
            onReset: () => setState(() {
              _search.clear();
              _filter = 'All results';
              _favorites = false;
            }),
          ),
        )
      else
        SliverList.builder(
          itemCount: targets.length,
          itemBuilder: (_, index) => _TargetRow(
            key: ValueKey(targets[index].key.value),
            engine: engine,
            target: targets[index],
            selected: false,
            compact: false,
            onTap: () => ItemProfilePage.open(
              context,
              engine: engine,
              target: targets[index],
            ),
          ),
        ),
    ],
  );

  Widget _actions() => PopupMenuButton<String>(
    tooltip: 'Monitor actions',
    icon: const Icon(Icons.more_horiz),
    onSelected: (value) {
      switch (value) {
        case 'settings':
          _settings();
        case 'report':
          _report();
        case 'session':
          _session();
        case 'baseline':
          engine.captureBaseline();
        case 'pin':
          _pin();
        case 'compact':
          _compact();
        case 'help':
          ShortcutsCheatsheetDialog.show(context);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'report', child: Text(AppStrings.report)),
      const PopupMenuItem(
        value: 'session',
        child: Text('Session & comparison'),
      ),
      PopupMenuItem(
        value: 'baseline',
        enabled: engine.results.values.any((h) => h.completed),
        child: const Text('Capture baseline'),
      ),
      if (widget.desktop) ...[
        PopupMenuItem(
          value: 'pin',
          child: Text(
            engine.settings.alwaysOnTop ? 'Unpin window' : 'Pin window',
          ),
        ),
        PopupMenuItem(
          value: 'compact',
          child: Text(
            engine.settings.compactMode
                ? 'Leave compact mode'
                : 'Enter compact mode',
          ),
        ),
      ],
      PopupMenuItem(
        value: 'settings',
        child: Text(
          _update?.isUpdateAvailable == true
              ? 'Settings · update available'
              : AppStrings.settings,
        ),
      ),
      const PopupMenuItem(value: 'help', child: Text('Keyboard shortcuts')),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final privacy = engine.settings.privacyMode;
      final compact = widget.desktop && engine.settings.compactMode;
      final targets = _group(_view).where((t) {
        final hit = engine.hitFor(t.key), name = targetName(engine, t);
        final matches = privacy
            ? name.toLowerCase().contains(_search.text.toLowerCase())
            : '${t.title} ${t.address} ${t.key.query}'.toLowerCase().contains(
                _search.text.toLowerCase(),
              );
        final status = switch (_filter) {
          'Needs attention' =>
            hit.status == HitStatus.fail ||
                hit.status == HitStatus.timeout ||
                hit.warning != null,
          'Responding' => hit.status == HitStatus.ok,
          'Not checked' => hit.status == HitStatus.idle,
          'Disabled' => !engine.enabled(t.key),
          _ => true,
        };
        return matches && status && (!_favorites || engine.favorite(t.key));
      }).toList();
      final selected = engine.targets
          .where((t) => t.key == _selected)
          .firstOrNull;
      return AppShortcutsWrapper(
        onToggleRun: () => engine.setRunning(!engine.isRunning),
        onOpenSettings: _settings,
        onCopyReport: _report,
        onTogglePin: widget.desktop ? _pin : null,
        onShowHelp: () => ShortcutsCheatsheetDialog.show(context),
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final split =
                    widget.desktop &&
                    bounds.maxWidth >= 1120 &&
                    MediaQuery.textScalerOf(context).scale(14) < 23 &&
                    !compact;
                final inset = bounds.maxWidth < 600 ? 16.0 : 24.0;
                if (MediaQuery.textScalerOf(context).scale(14) >= 23) {
                  return _largeTextMonitor(targets);
                }
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        inset,
                        compact ? 8 : 12,
                        inset,
                        8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.network_check, size: 24, color: kOk),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () =>
                                engine.setRunning(!engine.isRunning),
                            icon: Icon(
                              engine.isRunning ? Icons.pause : Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(
                              engine.isRunning
                                  ? AppStrings.pause
                                  : AppStrings.resume,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _actions(),
                        ],
                      ),
                    ),
                    if (!compact)
                      Padding(
                        padding: EdgeInsets.fromLTRB(inset, 12, inset, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppStrings.monitor,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            if (bounds.maxWidth > 700)
                              OutlinedButton.icon(
                                onPressed: _session,
                                icon: const Icon(
                                  Icons.compare_arrows,
                                  size: 18,
                                ),
                                label: const Text('Session & comparison'),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 4, inset, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            engine.isRunning && engine.adapterAvailable
                                ? Icons.circle
                                : Icons.pause_circle_outline,
                            size: 9,
                            color: engine.isRunning && engine.adapterAvailable
                                ? kOk
                                : kTo,
                          ),
                          Text(
                            engine.runLabel,
                            style: TextStyle(
                              color: engine.adapterAvailable ? kMute : kTo,
                              fontSize: 12,
                            ),
                          ),
                          const Text('·', style: TextStyle(color: kMute)),
                          Text(
                            contextName(engine),
                            style: const TextStyle(color: kMute, fontSize: 12),
                          ),
                          if (privacy)
                            const Tooltip(
                              message: 'Privacy mode is on',
                              child: Icon(
                                Icons.visibility_off_outlined,
                                size: 14,
                                color: kMute,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (engine.persistenceError != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: inset),
                        child: Text(
                          engine.persistenceError!,
                          style: const TextStyle(color: kTo),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: _ViewTab(
                                title: [
                                  AppStrings.websites,
                                  AppStrings.dns,
                                  AppStrings.advanced,
                                ][i],
                                selected: _view == i,
                                count: _group(i)
                                    .where(
                                      (t) =>
                                          engine.enabled(t.key) &&
                                          engine.hitFor(t.key).status ==
                                              HitStatus.ok,
                                    )
                                    .length,
                                total: _group(
                                  i,
                                ).where((t) => engine.enabled(t.key)).length,
                                onTap: () => setState(() {
                                  _view = i;
                                  _selected = null;
                                }),
                                compact: compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    inset,
                                    16,
                                    inset,
                                    12,
                                  ),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _search,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search ${['websites', 'DNS checks', 'advanced checks'][_view]}',
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            size: 20,
                                          ),
                                          suffixIcon: _search.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Clear search',
                                                  onPressed: () {
                                                    _search.clear();
                                                    setState(() {});
                                                  },
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          PopupMenuButton<String>(
                                            tooltip: 'Filter results',
                                            initialValue: _filter,
                                            onSelected: (v) =>
                                                setState(() => _filter = v),
                                            itemBuilder: (_) =>
                                                [
                                                      'All results',
                                                      'Needs attention',
                                                      'Responding',
                                                      'Not checked',
                                                      'Disabled',
                                                    ]
                                                    .map(
                                                      (v) => PopupMenuItem(
                                                        value: v,
                                                        child: Text(v),
                                                      ),
                                                    )
                                                    .toList(),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 14,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _filter,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.expand_more,
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          FilterChip(
                                            label: const Text('Favorites'),
                                            selected: _favorites,
                                            onSelected: (v) =>
                                                setState(() => _favorites = v),
                                            avatar: const Icon(
                                              Icons.star_border,
                                              size: 16,
                                            ),
                                          ),
                                          Text(
                                            '${targets.length} targets',
                                            style: const TextStyle(
                                              color: kMute,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                                Expanded(
                                  child: targets.isEmpty
                                      ? _EmptyResults(
                                          onReset: () {
                                            setState(() {
                                              _search.clear();
                                              _filter = 'All results';
                                              _favorites = false;
                                            });
                                          },
                                        )
                                      : ListView.builder(
                                          key: PageStorageKey('monitor-$_view'),
                                          itemCount: targets.length,
                                          itemBuilder: (context, index) {
                                            final t = targets[index];
                                            return _TargetRow(
                                              key: ValueKey(t.key.value),
                                              engine: engine,
                                              target: t,
                                              selected:
                                                  split && _selected == t.key,
                                              compact: compact,
                                              onTap: () {
                                                if (split) {
                                                  setState(
                                                    () => _selected = t.key,
                                                  );
                                                } else {
                                                  ItemProfilePage.open(
                                                    context,
                                                    engine: engine,
                                                    target: t,
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: inset,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Freshness(
                                          at: engine.latestAt,
                                          prefix: 'Last result · ',
                                        ),
                                      ),
                                      if (bounds.maxWidth > 500)
                                        const Text(
                                          AppStrings.sessionOnly,
                                          style: TextStyle(
                                            color: kMute,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (split)
                            Container(
                              width: 370,
                              decoration: const BoxDecoration(
                                color: kCard,
                                border: Border(left: BorderSide(color: kLine)),
                              ),
                              child: selected == null
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.touch_app_outlined,
                                              size: 28,
                                              color: kMute,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Select a target',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Inspect its latest result, recent checks and connection details here.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: kMute),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : TargetInspector(
                                      engine: engine,
                                      target: selected,
                                      onClose: () =>
                                          setState(() => _selected = null),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.title,
    required this.selected,
    required this.count,
    required this.total,
    required this.onTap,
    required this.compact,
  });
  final String title;
  final bool selected, compact;
  final int count, total;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '$title, $count of $total responding',
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 12 : 14,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? kPaper : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected ? kPaper : kMute,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                '$count / $total responding',
                style: mono.copyWith(fontSize: 10, color: kMute),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    super.key,
    required this.engine,
    required this.target,
    required this.onTap,
    required this.selected,
    required this.compact,
  });
  final ProbeEngine engine;
  final ProbeTarget target;
  final VoidCallback onTap;
  final bool selected, compact;
  @override
  Widget build(BuildContext context) {
    final hit = engine.hitFor(target.key),
        checking = engine.executionFor(target.key) == ProbeExecution.checking;
    final enabled = engine.enabled(target.key);
    return Material(
      color: selected ? kCardMuted : kInk,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kLine, width: .5)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            compact ? 7 : 12,
            4,
            compact ? 7 : 12,
          ),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final wide =
                  bounds.maxWidth > 620 &&
                  MediaQuery.textScalerOf(context).scale(14) < 22;
              return Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: StatusMark(hit: hit, checking: checking),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: wide ? 3 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          targetName(engine, target),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: enabled ? kPaper : kMute,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (!wide)
                          Text(
                            !enabled
                                ? 'Excluded from monitoring'
                                : hit.status == HitStatus.ok
                                ? '${hit.warning != null ? 'Responded' : 'Reachable'}${hit.ms != null ? ' · ${hit.ms} ms' : ''}'
                                : hit.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled ? statusColor(hit.status) : kMute,
                            ),
                          )
                        else
                          Text(
                            target.category == ItemCategory.domain
                                ? targetAddress(engine, target)
                                : '${target.categoryLabel}${target.regional ? ' · Regional' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kMute, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Text(
                        enabled ? hit.label : 'Disabled',
                        style: TextStyle(
                          color: statusColor(hit.status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 82,
                      child: Text(
                        hit.ms == null ? '—' : '${hit.ms} ms',
                        style: mono,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    tooltip: engine.favorite(target.key)
                        ? 'Remove favorite'
                        : 'Add favorite',
                    onPressed: () => engine.toggleFavorite(target.key),
                    icon: Icon(
                      engine.favorite(target.key)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                      color: engine.favorite(target.key) ? kTo : kMute,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Target actions',
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'enabled') {
                        engine.setEnabled(target.key, !enabled);
                      }
                      if (value == 'check') engine.runNow(target);
                      if (value == 'details') onTap();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('View details'),
                      ),
                      PopupMenuItem(
                        value: 'check',
                        enabled: !checking,
                        child: const Text(AppStrings.checkNow),
                      ),
                      PopupMenuItem(
                        value: 'enabled',
                        child: Text(
                          enabled
                              ? 'Exclude from monitoring'
                              : 'Include in monitoring',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 28, color: kMute),
          const SizedBox(height: 16),
          const Text('No matching targets'),
          const SizedBox(height: 8),
          const Text(
            'Try a different search or filter. Add custom websites in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMute),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('Reset filters')),
        ],
      ),
    ),
  );
}
