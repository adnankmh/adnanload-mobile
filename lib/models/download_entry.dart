class DownloadEntry {
  final String id;
  final String url;
  String name;
  String kind;
  String status;
  String quality;
  String path;
  String error;
  double progress;
  double speed;
  int addedAt;
  bool isPlaylist;
  String playlistItems;
  String audioFormat;
  String expectedSha256;
  String actualSha256;
  int scheduledAt;
  bool autoQueue;
  bool nativeQueued;
  bool scheduledExternally;
  int priority;
  int retryAttempts;
  int retryAt;


  DownloadEntry({required this.id, required this.url, required this.name,
    required this.kind, required this.status, this.quality = 'best',
    this.path = '', this.error = '', this.progress = 0, this.speed = 0,
    required this.addedAt, this.isPlaylist = false,
    this.playlistItems = '', this.audioFormat = 'mp3',
    this.expectedSha256 = '', this.actualSha256 = '', this.scheduledAt = 0,
    this.autoQueue = false, this.nativeQueued = false,
    this.scheduledExternally = false, this.priority = 5,
    this.retryAttempts = 0, this.retryAt = 0});

  // Corrupted or older history must not cause an otherwise recoverable
  // download to disappear from the queue. Native progress callbacks can also
  // supply non-finite values that jsonEncode cannot serialize.
  // Dart DateTime supports at most +/- 8.64e15 milliseconds since epoch.
  // Prevent damaged history from persisting unusable schedule timestamps.
  static const int _maxSafeTimestamp = 8640000000000000;

  static double _progress(Object? value) {
    if (value is! num || !value.isFinite) return 0;
    return value.toDouble().clamp(0.0, 1.0).toDouble();
  }

  static double _speed(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return 0;
    return value.toDouble();
  }

  static int _integer(Object? value, int fallback, {int? min, int? max}) {
    if (value is! num || !value.isFinite) return fallback;
    final number = value.toInt();
    if (min != null && number < min) return min;
    if (max != null && number > max) return max;
    return number;
  }

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    id: json['id']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'direct',
    status: json['status']?.toString() ?? 'waiting',
    quality: json['quality']?.toString() ?? 'best',
    path: json['path']?.toString() ?? '',
    error: json['error']?.toString() ?? '',
    progress: _progress(json['progress']),
    speed: _speed(json['speed']),
    addedAt: _integer(json['addedAt'], DateTime.now().millisecondsSinceEpoch,
      min: 0, max: _maxSafeTimestamp),
    isPlaylist: json['isPlaylist'] == true,
    playlistItems: json['playlistItems']?.toString() ?? '',
    audioFormat: json['audioFormat']?.toString() ?? 'mp3',
    expectedSha256: json['expectedSha256']?.toString() ?? '',
    actualSha256: json['actualSha256']?.toString() ?? '',
    scheduledAt: _integer(json['scheduledAt'], 0,
      min: 0, max: _maxSafeTimestamp),
    autoQueue: json['autoQueue'] == true,
    nativeQueued: json['nativeQueued'] == true,
    scheduledExternally: json['scheduledExternally'] == true,
    priority: _integer(json['priority'], 5, min: 0, max: 10),
    retryAttempts: _integer(json['retryAttempts'], 0, min: 0, max: 3),
    retryAt: _integer(json['retryAt'], 0, min: 0, max: _maxSafeTimestamp),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'url': url, 'name': name, 'kind': kind, 'status': status,
    'quality': quality, 'path': path, 'error': error, 'progress': _progress(progress),
    'speed': _speed(speed),
    'addedAt': _integer(addedAt, 0, min: 0, max: _maxSafeTimestamp),
    'isPlaylist': isPlaylist, 'playlistItems': playlistItems, 'audioFormat': audioFormat,
    'expectedSha256': expectedSha256, 'actualSha256': actualSha256,
    'scheduledAt': _integer(scheduledAt, 0, min: 0, max: _maxSafeTimestamp),
    'autoQueue': autoQueue,
    'nativeQueued': nativeQueued, 'scheduledExternally': scheduledExternally,
    'priority': _integer(priority, 5, min: 0, max: 10),
    'retryAttempts': _integer(retryAttempts, 0, min: 0, max: 3),
    'retryAt': _integer(retryAt, 0, min: 0, max: _maxSafeTimestamp),
  };
}
