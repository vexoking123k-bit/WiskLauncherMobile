import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../theme/app_theme.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _scroll = ScrollController();
  late final List<LogEntry> _entries;
  StreamSubscription<LogEntry>? _sub;
  // Default to info — debug fires on every asset/library file (thousands per
  // install) and drowns out the meaningful messages.
  LogLevel _minLevel = LogLevel.info;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _entries = List.of(AppLogger.instance.recent);
    _sub = AppLogger.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _entries.add(e);
        if (_entries.length > 4000) {
          _entries.removeRange(0, _entries.length - 4000);
        }
      });
      if (_autoScroll) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Color _colorFor(LogLevel l) => switch (l) {
        LogLevel.debug => AppTheme.textLo,
        LogLevel.info  => AppTheme.textHi,
        LogLevel.warn  => AppTheme.warn,
        LogLevel.error => AppTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    final filtered =
        _entries.where((e) => e.level.index >= _minLevel.index).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<LogLevel>(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list_rounded),
            initialValue: _minLevel,
            onSelected: (l) => setState(() => _minLevel = l),
            itemBuilder: (_) => [
              for (final l in LogLevel.values)
                PopupMenuItem(value: l, child: Text(l.name.toUpperCase())),
            ],
          ),
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(_autoScroll
                ? Icons.vertical_align_bottom_rounded
                : Icons.pause_circle_outline_rounded),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: filtered.map((e) => e.format()).join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied logs to clipboard')));
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              AppLogger.instance.clear();
              setState(() => _entries.clear());
            },
          ),
        ],
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No logs yet.\nThe launcher will narrate every step it takes here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textLo, height: 1.4)),
              ),
            )
          : Container(
              color: AppTheme.bgPanel,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: filtered.length,
                itemExtent: 18,
                itemBuilder: (_, i) {
                  final e = filtered[i];
                  return Text(
                    e.format(),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _colorFor(e.level),
                      height: 1.4,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
