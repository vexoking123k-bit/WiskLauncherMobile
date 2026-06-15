enum DownloadState { queued, running, paused, completed, failed, cancelled }

/// A single file download tracked by the download manager. We persist these so
/// resumes survive app restarts.
class DownloadTask {
  final String id;
  final String url;
  final String destinationPath;
  final int? expectedSize;
  final String? expectedSha1;
  final String label;       // user-facing
  final DateTime created;

  DownloadState state;
  int bytesDownloaded;
  String? errorMessage;

  DownloadTask({
    required this.id,
    required this.url,
    required this.destinationPath,
    required this.label,
    required this.created,
    this.expectedSize,
    this.expectedSha1,
    this.state = DownloadState.queued,
    this.bytesDownloaded = 0,
    this.errorMessage,
  });

  double get progress {
    final s = expectedSize;
    if (s == null || s == 0) return 0;
    return (bytesDownloaded / s).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'destinationPath': destinationPath,
        'expectedSize': expectedSize,
        'expectedSha1': expectedSha1,
        'label': label,
        'created': created.toIso8601String(),
        'state': state.name,
        'bytesDownloaded': bytesDownloaded,
        'errorMessage': errorMessage,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String,
        url: json['url'] as String,
        destinationPath: json['destinationPath'] as String,
        expectedSize: (json['expectedSize'] as num?)?.toInt(),
        expectedSha1: json['expectedSha1'] as String?,
        label: json['label'] as String,
        created: DateTime.parse(json['created'] as String),
        state: DownloadState.values
            .firstWhere((s) => s.name == json['state'], orElse: () => DownloadState.queued),
        bytesDownloaded: (json['bytesDownloaded'] as num?)?.toInt() ?? 0,
        errorMessage: json['errorMessage'] as String?,
      );
}
