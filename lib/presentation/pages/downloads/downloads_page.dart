import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/download_task.dart';
import '../../providers.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = ref.watch(downloadManagerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: StreamBuilder<List<DownloadTask>>(
        stream: dm.stream,
        initialData: dm.snapshot,
        builder: (_, snap) {
          final list = snap.data ?? const <DownloadTask>[];
          if (list.isEmpty) {
            return const Center(child: Text('No downloads.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              return Card(
                child: ListTile(
                  title: Text(t.label),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t.state.name} — ${(t.progress * 100).toStringAsFixed(0)}%'),
                    LinearProgressIndicator(value: t.progress == 0 ? null : t.progress),
                    if (t.errorMessage != null) Text(t.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.state == DownloadState.running)
                      IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () => dm.cancel(t.id)),
                    if (t.state == DownloadState.failed || t.state == DownloadState.cancelled)
                      IconButton(icon: const Icon(Icons.refresh), onPressed: () => dm.retry(t.id)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
