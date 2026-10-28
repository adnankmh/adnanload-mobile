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

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    id: json['id']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'direct',
    status: json['status']?.toString() ?? 'waiting',
    quality: json['quality']?.toString() ?? 'best',
    path: json['path']?.toString() ?? '',
    error: json['error']?.toString() ?? '',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    speed: (json['speed'] as num?)?.toDouble() ?? 0,
    addedAt: (json['addedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    isPlaylist: json['isPlaylist'] == true,
    playlistItems: json['playlistItems']?.toString() ?? '',
    audioFormat: json['audioFormat']?.toString() ?? 'mp3',
    expectedSha256: json['expectedSha256']?.toString() ?? '',
    actualSha256: json['actualSha256']?.toString() ?? '',
    scheduledAt: (json['scheduledAt'] as num?)?.toInt() ?? 0,
    autoQueue: json['autoQueue'] == true,
    nativeQueued: json['nativeQueued'] == true,
    scheduledExternally: json['scheduledExternally'] == true,
    priority: (json['priority'] as num?)?.toInt() ?? 5,
    retryAttempts: ((json['retryAttempts'] as num?)?.toInt() ?? 0).clamp(0, 3).toInt(),
    retryAt: (json['retryAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'url': url, 'name': name, 'kind': kind, 'status': status,
    'quality': quality, 'path': path, 'error': error, 'progress': progress,
    'speed': speed, 'addedAt': addedAt,
    'isPlaylist': isPlaylist, 'playlistItems': playlistItems, 'audioFormat': audioFormat,
    'expectedSha256': expectedSha256, 'actualSha256': actualSha256,
    'scheduledAt': scheduledAt, 'autoQueue': autoQueue,
    'nativeQueued': nativeQueued, 'scheduledExternally': scheduledExternally,
    'priority': priority,
    'retryAttempts': retryAttempts, 'retryAt': retryAt,
  };
}
