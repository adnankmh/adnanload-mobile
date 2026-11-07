import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

import '../core/url_guard.dart';
import '../core/language_preference.dart';
import '../core/media_failure.dart';
import '../core/media_output.dart';
import '../core/smart_link.dart';
import '../core/playlist_rules.dart';
import '../core/playlist_selection.dart';
import '../core/transfer_policy.dart';
import '../core/range_probe.dart';
import '../core/direct_completion_verifier.dart';
import '../core/download_metrics.dart';
import 'privacy_lock.dart';
import 'backup_service.dart';
import 'storage_audit.dart';
import 'crash_journal.dart';
import 'android_schedule_service.dart';
import '../models/download_entry.dart';

/// Central application service. The background-downloader database owns native
/// transfer states, while SharedPreferences stores only UI metadata/history.
class DownloadRepository extends ChangeNotifier {
  final PrivacyLock privacyLock = PrivacyLock();
  final List<DownloadEntry> _items = [];
  List<DownloadEntry> get items => List.unmodifiable(_items);
  StreamSubscription<bd.TaskUpdate>? _directSub;
  StreamSubscription<DownloadProgress>? _mediaSub;
  StreamSubscription<DownloadError>? _mediaErrors;
  Timer? _persistTimer;
  Future<void> _persistTail = Future<void>.value();
  Timer? _queueTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<BatteryState>? _batterySub;
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();
  DateTime? _lastNetworkProbe;
  List<ConnectivityResult> _networkTypes = const [ConnectivityResult.none];
  int _batteryPercent = 100;
  bool _isCharging = false; // Unknown charging state must not bypass opt-in gate.
  int crashCount = 0;
  bool automaticRetry = true;
  int batteryFloor = 0;
  final Set<String> _foregroundRequestIds = {};
  final Set<String> _verifyingDirectIds = {};
  final List<String> _diagnosticEvents = [];
  List<String> get diagnosticEvents => List.unmodifiable(_diagnosticEvents);
  DownloadMetrics get metrics => DownloadMetrics.fromEntries(_items);
  bool _pumping = false;
  double fontScale = 1.0;
  int maxConcurrent = 3;
  int parallelChunks = 4;
  int storageLimitMb = 0; // 0 = unlimited, app-managed files only
  final List<String> bookmarks = [];
  SharedPreferences? _prefs;
  bool _initializedMedia = false;
  Future<bool>? _mediaInitFuture;
  bool _notificationsAsked = false;
  bool wifiOnly = false;
  bool chargingOnly = false;
  bool notifications = true;
  bool autoOpenSafeFiles = false;
  bool autoStartSharedLinks = false;
  bool _appVisible = true;
  bool autoUpdateMediaEngine = false;
  bool _updateInProgress = false;
  String theme = 'dark';
  String language = 'ar';

  DownloadEntry? entry(String id) {
    for (final item in _items) { if (item.id == id) return item; }
    return null;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    crashCount = await CrashJournal.crashCount();
    theme = _prefs!.getString('theme') ?? 'dark';
    if (!const {'dark', 'light', 'gold'}.contains(theme)) theme = 'dark';
    language = LanguagePreference.normalize(_prefs!.get('language'));
    wifiOnly = _prefs!.getBool('wifiOnly') ?? false;
    chargingOnly = _prefs!.getBool('chargingOnly') ?? false;
    batteryFloor = _prefs!.getInt('batteryFloor') ?? 0;
    if (!const {0, 15, 25, 40}.contains(batteryFloor)) batteryFloor = 0;
    automaticRetry = _prefs!.getBool('automaticRetry') ?? true;
    notifications = _prefs!.getBool('notifications') ?? true;
    autoOpenSafeFiles = _prefs!.getBool('autoOpenSafeFiles') ?? false;
    autoStartSharedLinks = _prefs!.getBool('autoStartSharedLinks') ?? false;
    autoUpdateMediaEngine = _prefs!.getBool('autoUpdateMediaEngine') ?? false;
    fontScale = (_prefs!.getDouble('fontScale') ?? 1.0).clamp(.9, 1.35).toDouble();
    maxConcurrent = (_prefs!.getInt('maxConcurrent') ?? 3).clamp(1, 6).toInt();
    parallelChunks = (_prefs!.getInt('parallelChunks') ?? 4).clamp(1, 8).toInt();
    storageLimitMb = (_prefs!.getInt('storageLimitMb') ?? 0).clamp(0, 102400).toInt();
    bookmarks.addAll(_prefs!.getStringList('bookmarks') ?? <String>[]);
    for (final jsonString in _prefs!.getStringList('history') ?? <String>[]) {
      try { _items.add(DownloadEntry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>)); }
      catch (_) { /* skip a corrupted single entry */ }
    }
    _directSub = bd.FileDownloader().updates.listen(_handleDirectUpdate);
    await bd.FileDownloader().start(autoCleanDatabase: false);
    _configureNotifications();
    await bd.FileDownloader().resumeFromBackground();
    _reconcileInterruptedMedia();
    await _reconcileScheduledDirect();
    await _reconcileInterruptedDirect();
    _event('Repository startup recovery completed');
    await _refreshDevicePolicy();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((types) {
      _networkTypes = types;
      _event('Connectivity changed');
      unawaited(_pump());
    });
    _batterySub = _battery.onBatteryStateChanged.listen((state) {
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      unawaited(_refreshDevicePolicy());
      unawaited(_pump());
    });
    _queueTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_refreshDevicePolicy());
      unawaited(_pump());
    });
    unawaited(_pump());
    notifyListeners();
  }

  void _event(String event) {
    // Only preselected aggregate event descriptions; no file names or URLs.
    _diagnosticEvents.add('${DateTime.now().toUtc().toIso8601String()} · $event');
    if (_diagnosticEvents.length > 80) _diagnosticEvents.removeAt(0);
  }

  Future<void> _refreshDevicePolicy() async {
    try {
      _networkTypes = await _connectivity.checkConnectivity();
      _batteryPercent = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      // Fail closed for Wi-Fi-only media when connectivity is unknown.
      _networkTypes = const [ConnectivityResult.none];
    }
    _lastNetworkProbe = DateTime.now();
    notifyListeners();
  }

  void setAppVisible(bool value) => _appVisible = value;

  /// Opening is opt-in and only for safe files while the app is foregrounded.
  void _maybeOpenCompleted(DownloadEntry item) {
    if (!autoOpenSafeFiles || !_appVisible || item.isPlaylist || item.path.isEmpty) return;
    if (SmartLink.category(item.name) == 'application') return;
    unawaited(OpenFilex.open(item.path).then((_) {}).catchError((Object _) {}));
  }

  Future<void> onForeground() async {
    await _refreshDevicePolicy();
    try { await bd.FileDownloader().resumeFromBackground(); }
    catch (_) { _event('Could not refresh Android background job events'); }
    await _reconcileScheduledDirect();
    // Retry interrupted completion checks after transient native lookup errors.
    await _reconcileInterruptedDirect();
    await _pump();
  }

  /// Detect jobs that the OS has already handed to the native downloader.
  /// Never create a second copy of a scheduled transfer while its native id exists.
  Future<void> _reconcileScheduledDirect() async {
    for (final item in _items.where((e) => e.scheduledExternally &&
        e.kind == 'direct' && e.status == 'waiting')) {
      try {
        final native = await bd.FileDownloader().taskForId(item.id);
        if (native != null) {
          item.nativeQueued = true;
          item.scheduledExternally = false;
          item.autoQueue = false;
        }
      } catch (_) { /* OS scheduling state may be unavailable briefly */ }
    }
    _persistSoon();
  }

  /// Recover direct jobs from the native Android database even when the UI
  /// snapshot predates the enqueue callback. Do not guess native task state
  /// after a platform-channel failure, and never silently recreate lost work.
  Future<void> _reconcileInterruptedDirect() async {
    const recoverable = {'running','submitting','waiting','paused','verifying'};
    // Snapshot the queue: callbacks and user actions may mutate it during await.
    for (final item in _items.where((e) => e.kind == 'direct' &&
        !e.scheduledExternally && recoverable.contains(e.status)).toList()) {
      // A live verification owns the result; a foreground reconciliation must
      // not turn it into a failure while hashing is still in progress.
      if (_verifyingDirectIds.contains(item.id)) continue;
      try {
        final task = await bd.FileDownloader().taskForId(item.id);
        // Native callbacks may have changed or removed the entry during await.
        if (!_items.contains(item) || !recoverable.contains(item.status) ||
            _verifyingDirectIds.contains(item.id)) continue;
        final wasVerifying = item.status == 'verifying';
        TransferPolicy.reconcileRestoredDirect(item,
            nativeTaskExists: task != null);
        if (wasVerifying && task != null && item.status == 'verifying' &&
            _verifyingDirectIds.add(item.id)) {
          // A completed native task still needs a fresh on-disk check. Do not
          // block startup on a potentially large SHA-256 calculation.
          unawaited(_verifyNativeTaskDestination(item, task));
        }
      } catch (_) {
        // A transient platform-channel failure is not evidence of missing work.
        // The next foreground reconciliation can retry this verification.
      }
    }
    _persistSoon();
  }

  /// A fresh URL is required for expired signed links. Never try to generate
  /// or bypass an expired site's authentication token.
  Future<void> retryWithNewUrl(DownloadEntry failed, String replacement) async {
    if (failed.status != 'error' && failed.status != 'canceled') {
      throw StateError('Only failed/canceled entries can use a new link');
    }
    if (UrlGuard.validate(replacement) == null) {
      throw const FormatException('Invalid replacement link');
    }
    await enqueue(url:replacement, name:failed.name, kind:failed.kind,
      quality:failed.quality, playlist:failed.isPlaylist,
      playlistItems:failed.playlistItems, audioFormat:failed.audioFormat,
      expectedSha256:failed.expectedSha256, priority:failed.priority);
    _event('Expired link replaced by user');
  }

  bool get mediaPolicyReady => TransferPolicy.mayStart(
    wifiOnly: wifiOnly, hasWifi: _networkTypes.contains(ConnectivityResult.wifi),
    hasNetwork: !_networkTypes.contains(ConnectivityResult.none) && _networkTypes.isNotEmpty,
    batteryPercent: _batteryPercent, charging: _isCharging,
    batteryFloor: batteryFloor, chargingOnly: chargingOnly,
  );

  String get networkDescription {
    if (_lastNetworkProbe == null) return 'unknown';
    if (_networkTypes.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (_networkTypes.contains(ConnectivityResult.mobile)) return 'Mobile';
    if (_networkTypes.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return _networkTypes.contains(ConnectivityResult.none) ? 'Offline' : 'Other';
  }

  String diagnosticsSummary() {
    final m = metrics;
    return 'ADNANLOAD 2.1.0 / Android\n'
      'Tasks: ${m.total} · Active: ${m.running} · Completed: ${m.completed}\n'
      'Waiting: ${m.waiting} · Failed: ${m.failed} · Retrying: ${m.retrying}\n'
      'Recorded crash events: $crashCount\n'
      'Network: $networkDescription · Battery: $_batteryPercent%\n'
      'Wi-Fi only: $wifiOnly · Charging only: $chargingOnly · Battery floor: $batteryFloor%\n'
      'Last local events (without file names or URLs):\n${_diagnosticEvents.join('\n')}';
  }

  Future<int> retryFailed() async {
    final failures = _items.where((item) => item.status == 'error').toList();
    for (final item in failures) {
      // Explicit user action: individual jobs keep their own quality and selection.
      await retry(item);
    }
    _event('Manual retry requested for ${failures.length} failed jobs');
    return failures.length;
  }

  bool _retryMediaIfTransient(DownloadEntry item, String reason) {
    if (!TransferPolicy.shouldRetry(reason, item.retryAttempts,
        enabled: automaticRetry) || item.status == 'canceled') return false;
    final nextAttempt = item.retryAttempts + 1;
    final delay = TransferPolicy.retryDelayForFailure(reason, nextAttempt);
    if (delay == null) return false; // honor excessive server backoff
    item.retryAttempts = nextAttempt;
    item.retryAt = DateTime.now().add(delay).millisecondsSinceEpoch;
    item.status = 'waiting';
    item.autoQueue = true;
    item.error = ''; // avoid storing repeated URL-bearing extractor errors
    _event('Media transient error; delayed retry ${item.retryAttempts}/3');
    return true;
  }

  void _configureNotifications() {
    // Notification permission is controlled by the Android OS; no forced prompts.
    // Running/paused notifications remain configured for Android 14+ UIDT,
    // even when optional completion alerts are disabled.
    bd.FileDownloader().configureNotification(
      running: bd.TaskNotification(language == 'ar' ? 'جارٍ التحميل' : 'Downloading', '{filename}'),
      paused: bd.TaskNotification(language == 'ar' ? 'متوقف مؤقتًا' : 'Paused', '{filename}'),
      complete: notifications ? bd.TaskNotification(language == 'ar' ? 'اكتمل التنزيل' : 'Download complete', '{filename}') : null,
      error: notifications ? bd.TaskNotification(language == 'ar' ? 'فشل التنزيل' : 'Download failed', '{filename}') : null,
      progressBar: true, tapOpensFile: false,
    );
  }

  Future<void> _ensureNotificationPermission() async {
    if (_notificationsAsked || !Platform.isAndroid) return;
    _notificationsAsked = true;
    try {
      final status = await bd.FileDownloader().permissions.status(bd.PermissionType.notifications);
      if (status != bd.PermissionStatus.granted) {
        await bd.FileDownloader().permissions.request(bd.PermissionType.notifications);
      }
    } catch (_) { /* download still works if notifications are denied */ }
  }

  void _reconcileInterruptedMedia() {
    for (final item in _items) {
      if (item.kind != 'direct' && {'running','submitting'}.contains(item.status)) {
        item.status = 'error';
        item.error = 'mediaInterrupted';
      }
    }
    _persistSoon();
  }

  void _handleDirectUpdate(bd.TaskUpdate update) {
    final item = entry(update.task.taskId);
    // Late native callbacks must not revive canceled or terminal jobs.
    if (item == null || item.kind != 'direct' ||
        const {'canceled', 'complete', 'error'}.contains(item.status)) return;
    // Ignore out-of-order progress/running updates during file verification.
    if (item.status == 'verifying' &&
        update is bd.TaskStatusUpdate &&
        !const {bd.TaskStatus.complete, bd.TaskStatus.failed, bd.TaskStatus.canceled}
            .contains(update.status)) return;
    if (update is bd.TaskStatusUpdate && update.status == bd.TaskStatus.complete) {
      // Native callbacks can be duplicated; verify each task only once.
      if (_verifyingDirectIds.add(item.id)) {
        unawaited(_verifyNativeTaskDestination(item, update.task));
      }
      return;
    }
    if (update is bd.TaskProgressUpdate) {
      if (update.progress >= 0 && update.progress <= 1) item.progress = update.progress;
      item.speed = update.hasNetworkSpeed ? update.networkSpeed : 0;
    } else if (update is bd.TaskStatusUpdate) {
      final status = update.status;
      item.status = switch (status) {
        bd.TaskStatus.running => 'running',
        bd.TaskStatus.complete => 'complete',
        bd.TaskStatus.paused => 'paused',
        bd.TaskStatus.failed => 'error',
        bd.TaskStatus.canceled => 'canceled',
        _ => 'waiting',
      };
      if (status == bd.TaskStatus.paused) {
        item.scheduledExternally = false;
        item.nativeQueued = false;
        unawaited(_pump());
      }
      if ({bd.TaskStatus.complete, bd.TaskStatus.failed, bd.TaskStatus.canceled}.contains(status)) {
        item.scheduledExternally = false;
        item.nativeQueued = false;
        unawaited(_pump());
      }
      if (update.exception != null) item.error = 'transferProblem';
    }
    notifyListeners();
    _persistSoon();
  }

  Future<void> _verifyNativeTaskDestination(DownloadEntry item, bd.Task task) async {
    bool isCurrent() => _items.contains(item) && item.status == 'verifying';
    try {
      if (!_items.contains(item) || item.status == 'canceled') return;
      item.status = 'verifying';
      notifyListeners();
      final result = await DirectCompletionVerifier.inspect(
        resolvePath: task.filePath,
        fallbackPath: item.path,
        expectedSha256: item.expectedSha256,
        isCurrent: isCurrent,
      );
      // Cancellation, removal, or a later native failure takes precedence over
      // a stale file/hash result, including one produced during an await.
      if (result == null || !isCurrent()) return;
      item.path = result.path;
      item.actualSha256 = result.actualSha256;
      item.status = result.status;
      item.error = result.error;
      if (item.status == 'complete') {
        item.progress = 1;
        _maybeOpenCompleted(item);
      }
    } finally {
      _verifyingDirectIds.remove(item.id);
      if (_items.contains(item) && item.status != 'canceled') {
        item.nativeQueued = false;
        item.scheduledExternally = false;
        notifyListeners();
        _persistSoon();
      }
      unawaited(_pump());
    }
  }

  Future<bool> _ensureMedia() => _mediaInitFuture ??= _initializeMedia();

  Future<bool> _initializeMedia() async {
    try {
      final init = await YoutubeDLFlutter.instance.initialize(enableFFmpeg: true, enableAria2c: false);
      if (!init.success) {
        _mediaInitFuture = null;
        return false;
      }
      _mediaSub ??= YoutubeDLFlutter.instance.onProgress.listen((p) {
        final item = entry(p.processId);
        if (item == null || item.status == 'canceled') return;
        item.progress = (p.progress / 100).clamp(0.0, 1.0);
        item.status = 'running';
        notifyListeners();
        _persistSoon();
      });
      _mediaErrors ??= YoutubeDLFlutter.instance.onError.listen((failure) {
        final item = entry(failure.processId);
        if (item != null && item.status != 'canceled') {
          item.error = MediaFailure.classify(failure.error.toString());
          _event('Media engine reported: ${item.error}');
          notifyListeners();
          _persistSoon();
        }
      });
      _initializedMedia = true;
      if(autoUpdateMediaEngine) unawaited(_checkMediaUpdateIfDue());
      return true;
    } catch (_) {
      _mediaInitFuture = null;
      return false;
    }
  }

  Future<MediaSnapshot?> inspectMedia(String url) async {
    if (UrlGuard.validate(url) == null || !await _ensureMedia()) return null;
    try {
      final info = await YoutubeDLFlutter.instance.getVideoInfo(url);
      return MediaSnapshot(title: info.title ?? '', uploader: info.uploader ?? '',
        thumbnail: info.thumbnail ?? '', durationSeconds: info.duration ?? 0,
        formats: info.formats?.length ?? 0);
    } catch (_) { return null; }
  }

  Future<String?> suggestMediaTitle(String url) async {
    if (!await _ensureMedia()) return null;
    try {
      final info = await YoutubeDLFlutter.instance.getVideoInfo(url);
      final title = info.title?.trim() ?? '';
      return title.isEmpty ? null : UrlGuard.safeName(title);
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueue({required String url, required String name, required String kind,
      String quality = 'best', bool startNow = true, bool playlist = false,
      String playlistItems = '', String audioFormat = 'mp3',
      String expectedSha256 = '', DateTime? schedule, int priority = 5}) async {
    if (storageLimitMb > 0 &&
        await StorageAudit.recordedBytes(_items) >= storageLimitMb*1024*1024) {
      throw StateError('storageQuotaReached');
    }
    final uri = UrlGuard.validate(url);
    if (uri == null) throw const FormatException('Invalid or unsafe URL');
    if (playlist && kind == 'direct') throw const FormatException('Playlists require video or audio mode');
    playlistItems = playlist ? PlaylistRules.parseItems(playlistItems) : '';
    if (!const {'mp3','m4a','flac','wav','opus'}.contains(audioFormat)) {
      throw const FormatException('Unsupported audio format');
    }
    final digest = expectedSha256.trim().toLowerCase();
    if (digest.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid SHA-256 digest');
    }
    final millis = DateTime.now().microsecondsSinceEpoch;
    final id = 'adnan_$millis';
    final cleanName = UrlGuard.uniqueName(
      name.trim().isEmpty ? UrlGuard.nameFromUrl(url) : name,
      _items.map((item) => item.name),
    );
    final item = DownloadEntry(id:id, url:uri.toString(), name:cleanName,
      kind:kind, status:'waiting', quality:quality, addedAt:DateTime.now().millisecondsSinceEpoch,
      isPlaylist: playlist, playlistItems: playlistItems, audioFormat: audioFormat,
      expectedSha256: digest, scheduledAt: schedule?.millisecondsSinceEpoch ?? 0,
      priority: priority.clamp(0,10).toInt(), autoQueue: startNow);
    _items.insert(0, item);
    // Persist before registering work: a process killed immediately after
    // scheduling must still show the job in restored history.
    if (schedule != null) await _persistNow();
    // WorkManager owns future direct starts even if the Flutter UI is closed.
    // If Android registration fails, the existing foreground scheduler remains.
    if (kind == 'direct' && startNow && schedule != null &&
        schedule.isAfter(DateTime.now())) {
      final registered = await AndroidScheduleService.register(
        id: item.id, url: item.url, name: item.name, when: schedule,
        wifiOnly: wifiOnly, chargingOnly: chargingOnly,
         priority: item.priority,
      );
      if (registered) {
        item.scheduledExternally = true;
        item.autoQueue = false;
        _event('Direct download registered with Android scheduler');
      } else {
        _event('Android scheduling unavailable; in-app fallback retained');
      }
    }
    if (kind == 'direct' && startNow && schedule == null) {
      _foregroundRequestIds.add(item.id);
    }
    if (schedule != null) { await _persistNow(); }
    else { _persistSoon(); }
    notifyListeners();
    if (startNow) unawaited(_pump());
  }

  /// Explicit numbered playlist entries become individually cancellable jobs.
  /// Entire playlists remain a single grouped task to avoid giant queues.
  Future<int> enqueueSelectedPlaylist({required String url, required String name,
      required String kind, required String positions, String quality = 'best',
      String audioFormat = 'mp3', bool startNow = true,
      DateTime? schedule, int priority = 5}) async {
    final selected = PlaylistSelection.expand(positions);
    if (selected.isEmpty) throw const FormatException('Select at least one playlist item');
    for (final index in selected) {
      await enqueue(url: url, name: '$name [$index]', kind: kind,
        quality: quality, playlist: true, playlistItems: '$index',
        audioFormat: audioFormat, startNow: startNow,
        schedule: schedule, priority: priority);
    }
    return selected.length;
  }

  Map<String,dynamic> createBackup() => BackupService.create(items:_items,
    bookmarks:bookmarks, theme:theme, language:language, wifiOnly:wifiOnly);

  /// Merge sanitized imported history, never overwrite downloaded files,
  /// and never automatically restart restored transfers.
  Future<int> restoreBackup(Map<String,dynamic> data) async {
    final imported = BackupService.validEntries(data);
    var count = 0;
    final existing = _items.map((e) => e.id).toSet();
    for (final item in imported) {
      if (existing.add(item.id)) { _items.add(item); count++; }
    }
    final restoredBookmarks = data['bookmarks'] as List;
    for (final value in restoredBookmarks) {
      if (value is String && UrlGuard.validate(value) != null &&
          !bookmarks.contains(value) && bookmarks.length < 150) bookmarks.add(value);
    }
    await _prefs?.setStringList('bookmarks',bookmarks);
    final prefs = data['preferences'];
    if (prefs is Map) {
      final newTheme = prefs['theme']?.toString();
      final newLang = prefs['language']?.toString();
      updateSettings(newTheme: const {'dark','light','gold'}.contains(newTheme) ? newTheme : null,
        newLanguage: LanguagePreference.isSupported(newLang) ? newLang : null,
        newWifiOnly: prefs['wifiOnly'] is bool ? prefs['wifiOnly'] as bool : null);
    }
    _persistSoon(); notifyListeners();
    return count;
  }

  /// Enqueues only when a free direct slot exists; media extraction is serialized.
  /// Deferred entries stay in history until the user explicitly starts them.
  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final awaiting = _items.where((x) =>
          TransferPolicy.readyToDispatch(x, now)).toList()
        ..sort((a,b) => a.priority.compareTo(b.priority));
      final activeDirectEntries = _items.where((x) =>
          x.kind == 'direct' && (x.nativeQueued || x.status == 'submitting'));
      var activeDirect = activeDirectEntries.length;
      final activeByHost = <String, int>{};
      for (final active in activeDirectEntries) {
        TransferPolicy.countDirectHost(active.url, activeByHost);
      }
      var mediaActive = _items.any((x) => x.kind != 'direct' && {'running','submitting'}.contains(x.status));
      // Best-effort soft app quota. Does not interrupt an already-running transfer.
      if (storageLimitMb > 0 &&
          await StorageAudit.recordedBytes(_items) >= storageLimitMb*1024*1024) return;
      for (final item in awaiting) {
        // The storage quota check above can suspend this pump. The user may
        // have paused, canceled, removed or rescheduled a snapshotted job.
        // Never submit a stale entry to the native downloader.
        if (!_items.contains(item) || !TransferPolicy.readyToDispatch(
            item, DateTime.now().millisecondsSinceEpoch)) continue;
        // The network/battery preflight is required for on-device media tasks.
        // Direct tasks already have an OS-managed Wi-Fi constraint.
        if (item.kind != 'direct' && !mediaPolicyReady) continue;
        // WorkManager handles future scheduled direct jobs; gate the local
        // fallback queue as well when the user opted into charging-only.
        if (item.kind == 'direct' && chargingOnly && !_isCharging) continue;
        if (item.kind == 'direct' && activeDirect >= maxConcurrent) continue;
        if (item.kind == 'direct' &&
            !TransferPolicy.mayStartDirectHost(item.url, activeByHost)) continue;
        if (item.kind != 'direct' && mediaActive) continue;
        item.autoQueue = false; item.status = 'submitting'; item.retryAt = 0;
        if (item.kind == 'direct') {
          activeDirect++;
          TransferPolicy.countDirectHost(item.url, activeByHost);
        } else {
          mediaActive = true;
        }
        // Do not await long media downloads while holding the queue lock.
        unawaited(start(item, userInitiated: _foregroundRequestIds.remove(item.id))
          .catchError((Object _) {}));
      }
    } finally {
      _pumping = false;
      notifyListeners();
      _persistSoon();
    }
  }

  Future<void> start(DownloadEntry item, {bool userInitiated = false}) async {
    if (!_items.contains(item) || item.status == 'canceled' || item.status == 'complete') return;
    if (UrlGuard.validate(item.url) == null) throw const FormatException('Unsafe URL');
    if (item.kind == 'direct') {
      if (item.scheduledExternally) {
        await AndroidScheduleService.cancel(item.id);
        item.scheduledExternally = false;
        item.scheduledAt = 0;
      }
      if (item.nativeQueued) return;
      bool stillSubmitting() => TransferPolicy.directSubmissionStillAllowed(
        item, isTracked: _items.contains(item),
      );
      if (!stillSubmitting()) return;
      // Native lookups and permission prompts are asynchronous. Cancel may
      // happen while either is pending; never revive a canceled task.
      final existing = await bd.FileDownloader().taskForId(item.id);
      if (!stillSubmitting()) return;
      if (existing != null) {
        item.nativeQueued = true;
        notifyListeners(); _persistSoon();
        return;
      }
      await _ensureNotificationPermission();
      if (!stillSubmitting()) return;
      notifyListeners();
      final chunks = parallelChunks > 1 && await RangeProbe.supportsSafeParallelDownload(Uri.parse(item.url))
          ? parallelChunks : 1;
      if (!stillSubmitting()) return;
      final task = bd.ParallelDownloadTask(
        taskId: item.id, url: item.url, filename: item.name,
        directory: 'ADNANLOAD', baseDirectory: bd.BaseDirectory.applicationDocuments,
        allowPause: true, retries: 5, chunks: chunks, priority: item.priority,
        requiresWiFi: wifiOnly, updates: bd.Updates.statusAndProgress,
        transferHints: userInitiated
          ? const {bd.TransferHint.userInitiated, bd.TransferHint.largeFile}
          : const {bd.TransferHint.largeFile},
      );
      try {
        // Resolve the canonical destination from the same native Task.
        // Android and plugin versions may choose different internal roots.
        item.path = await task.filePath();
        if (!stillSubmitting()) return;
        final queued = await bd.FileDownloader().enqueue(task);
        if (!queued) throw StateError('Unable to enqueue download');
        // Cancel may have raced the native enqueue itself. A second native
        // cancellation closes that window even if the earlier cancel call
        // ran before Android registered the task.
        if (!_items.contains(item) || item.status == 'canceled') {
          await bd.FileDownloader().cancelTaskWithId(item.id);
          return;
        }
        _event('Native download successfully queued');
        // A native status callback may have arrived before enqueue returned.
        // Never replace a running or failed state with stale "waiting".
        if (const {'submitting', 'waiting', 'running'}.contains(item.status)) {
          item.nativeQueued = true;
          if (item.status == 'submitting') item.status = 'waiting';
        }
      } catch (e) {
        if (!_items.contains(item) || item.status == 'canceled') return;
        item.status = 'error'; item.error = 'nativeQueueFailed'; item.nativeQueued = false;
        _event('Native enqueue failed');
        unawaited(_pump());
        rethrow;
      } finally { notifyListeners(); _persistSoon(); }
      return;
    }
    if (!Platform.isAndroid) throw UnsupportedError('On-device media extraction is Android-only in this release.');
    if (!await _ensureMedia()) {
      item.status = 'error'; item.error = 'mediaInitFailed';
      notifyListeners(); _persistSoon();
      throw StateError(item.error);
    }
    item.status = 'running'; item.error = ''; notifyListeners(); _persistSoon();
    final docs = await getApplicationDocumentsDirectory();
    final output = MediaOutput.jobDirectory(
      Directory('${docs.path}/ADNANLOAD/media'), item.id);
    await output.create(recursive: true);
    final basename = MediaOutput.basename(item.name);
    // A playlist MUST NOT write every entry under one constant basename.
    // yt-dlp resolves playlist metadata and assigns a unique item filename.
    final template = item.isPlaylist
        ? '$basename/%(playlist_index)03d - %(title).160B [%(id)s].%(ext)s'
        : '$basename.%(ext)s';
    final extraOptions = <String, String>{
      '--retries':'8', '--fragment-retries':'8',
      '--no-overwrites':'',
      if (item.isPlaylist && item.playlistItems.isNotEmpty)
        '--playlist-items':item.playlistItems,
    };
    final format = switch (item.quality) {
      'p2160' => 'bestvideo[height<=2160]+bestaudio/best[height<=2160]/best',
      'p1440' => 'bestvideo[height<=1440]+bestaudio/best[height<=1440]/best',
      'p360' => 'bestvideo[height<=360]+bestaudio/best[height<=360]/best',
      'p1080' => 'bestvideo[height<=1080]+bestaudio/best[height<=1080]/best',
      'p720' => 'bestvideo[height<=720]+bestaudio/best[height<=720]/best',
      'p480' => 'bestvideo[height<=480]+bestaudio/best[height<=480]/best',
      _ => 'bestvideo+bestaudio/best',
    };
    try {
      final result = await YoutubeDLFlutter.instance.download(DownloadRequest(
        url: item.url, outputPath: output.path, outputTemplate: template,
        processId: item.id,
        noPlaylist: !item.isPlaylist,
        format: item.kind == 'mp3' ? 'bestaudio/best' : format,
        extractAudio: item.kind == 'mp3',
        audioFormat: item.kind == 'mp3' ? item.audioFormat : null,
        audioQuality: item.kind == 'mp3' ? 0 : null,
        customOptions: extraOptions,
        embedMetadata: true, embedThumbnail: false,
      ));
      if (item.status == 'canceled') return;
      if (result.status == OperationStatus.success) {
        // Only mark success once the output exists on disk.
        // The engine can report success with an empty outputPath or a new
        // extension after FFmpeg conversion. Inspect the files it produced.
        final playlistDir = Directory('${output.path}/$basename');
        if (item.isPlaylist) {
          item.path = playlistDir.path;
        } else {
          item.path = await MediaOutput.singleFile(output, basename, result.outputPath) ?? '';
        }
        final produced = item.isPlaylist
            ? await MediaOutput.hasPlaylistMedia(playlistDir)
            : item.path.isNotEmpty;
        item.status = produced ? 'complete' : 'error';
        item.error = produced ? '' : 'downloadedFileMissing';
        if (produced) {
          if (!item.isPlaylist) item.name = item.path.split(Platform.pathSeparator).last;
          item.progress = 1;
          _maybeOpenCompleted(item);
        }
      } else {
        final failure = result.errorMessage ?? 'Media download failed';
        if (!_retryMediaIfTransient(item, failure)) {
          item.status = 'error'; item.error = MediaFailure.classify(failure); _event('Media download failed: ${item.error}');
        }
      }
    } catch (e) {
      if (item.status != 'canceled' && !_retryMediaIfTransient(item, e.toString())) {
        item.status = 'error'; item.error = MediaFailure.classify(e.toString()); _event('Media download exception: ${item.error}');
      }
    } finally { notifyListeners(); _persistSoon(); unawaited(_pump()); }
  }

  Future<void> pause(DownloadEntry item) async {
    if (item.kind != 'direct' || !_items.contains(item)) return;
    // Pausing a job still in our Dart-side queue must prevent _pump from
    // submitting it. Pausing native transfers is delegated to Android.
    if (!item.nativeQueued && item.status == 'waiting') {
      item.autoQueue = false;
      item.status = 'paused';
      notifyListeners(); _persistSoon();
      return;
    }
    final task = await bd.FileDownloader().taskForId(item.id);
    if (task is bd.DownloadTask) await bd.FileDownloader().pause(task);
  }

  Future<void> resume(DownloadEntry item) async {
    if (item.kind != 'direct') return;
    if (item.scheduledExternally) {
      // Manual resume means start now instead of its future schedule.
      await AndroidScheduleService.cancel(item.id);
      item.scheduledExternally = false;
      item.scheduledAt = 0;
      item.autoQueue = true;
      notifyListeners(); _persistSoon();
      unawaited(_pump());
      return;
    }
    final task = await bd.FileDownloader().taskForId(item.id);
    if (task is bd.DownloadTask) {
      await bd.FileDownloader().resume(task);
    } else if (TransferPolicy.requeueDeferredDirect(item)) {
      // A locally paused item must become waiting before the queue can see it.
      // Do not recreate missing native jobs: those require explicit retry.
      notifyListeners(); _persistSoon();
      unawaited(_pump());
    }
  }

  Future<void> cancel(DownloadEntry item) async {
    if (!_items.contains(item)) return;
    // Revoke the Dart-side submission immediately. Platform cancellation may
    // await a task that has not yet been registered by an in-flight enqueue.
    TransferPolicy.markCanceled(item);
    _foregroundRequestIds.remove(item.id);
    notifyListeners(); _persistSoon();
    try {
      if (item.scheduledExternally) {
        await AndroidScheduleService.cancel(item.id);
        item.scheduledExternally = false;
      }
      if (item.kind == 'direct') {
        await bd.FileDownloader().cancelTaskWithId(item.id);
      } else if (_initializedMedia) {
        await YoutubeDLFlutter.instance.cancelDownload(item.id);
      }
    } finally {
      notifyListeners(); _persistSoon(); unawaited(_pump());
    }
  }

  Future<void> retry(DownloadEntry item) async {
    if (!_items.contains(item)) return;
    // Keep the original failure entry until a replacement is accepted.
    await enqueue(url:item.url, name:item.name, kind:item.kind, quality:item.quality,
        playlist:item.isPlaylist, playlistItems:item.playlistItems,
        audioFormat:item.audioFormat, expectedSha256:item.expectedSha256,
        priority:item.priority);
    _items.remove(item);
    notifyListeners();
    _persistSoon();
  }

  Future<void> remove(DownloadEntry item) async {
    if (!_items.contains(item)) return;
    // Await native cancellation before removing the visible row. Avoids a
    // background job continuing invisibly after the user deleted its entry.
    if ({'running', 'waiting', 'paused', 'submitting', 'verifying'}
        .contains(item.status) || item.scheduledExternally || item.nativeQueued) {
      await cancel(item);
    }
    _items.remove(item);
    _foregroundRequestIds.remove(item.id);
    notifyListeners();
    await _persistNow();
  }

  void updateSettings({String? newTheme, String? newLanguage, bool? newWifiOnly,
    bool? newAutoOpenSafeFiles, bool? newAutoStartSharedLinks, bool? newNotifications, bool? newAutoUpdateMediaEngine, int? newMaxConcurrent, int? newParallelChunks, double? newFontScale,
    int? newBatteryFloor, bool? newAutomaticRetry, int? newStorageLimitMb,
     bool? newChargingOnly}) {
    if(newStorageLimitMb != null){
      storageLimitMb = newStorageLimitMb.clamp(0,102400).toInt();
    }
    if (newTheme != null && const {'dark','light','gold'}.contains(newTheme)) theme = newTheme;
    if (LanguagePreference.isSupported(newLanguage)) language = newLanguage!;
    if (newWifiOnly != null) wifiOnly = newWifiOnly;
    if (newChargingOnly != null) chargingOnly = newChargingOnly;
    if (newNotifications != null) notifications = newNotifications;
    if (newAutoOpenSafeFiles != null) autoOpenSafeFiles = newAutoOpenSafeFiles;
    if (newAutoStartSharedLinks != null) autoStartSharedLinks = newAutoStartSharedLinks;
    if (newAutomaticRetry != null) automaticRetry = newAutomaticRetry;
    if (newBatteryFloor != null && const {0,15,25,40}.contains(newBatteryFloor)) batteryFloor = newBatteryFloor;
    if (newAutoUpdateMediaEngine != null) autoUpdateMediaEngine = newAutoUpdateMediaEngine;
    if (newFontScale != null) fontScale = newFontScale.clamp(.9,1.35).toDouble();
    if (newMaxConcurrent != null) maxConcurrent = newMaxConcurrent.clamp(1,6).toInt();
    if (newParallelChunks != null) parallelChunks = newParallelChunks.clamp(1,8).toInt();
    _prefs?.setString('theme',theme);
    _prefs?.setString('language',language);
    _prefs?.setBool('wifiOnly',wifiOnly);
    _prefs?.setBool('chargingOnly',chargingOnly);
    _prefs?.setBool('notifications',notifications);
    _prefs?.setBool('autoOpenSafeFiles',autoOpenSafeFiles);
    _prefs?.setBool('autoStartSharedLinks',autoStartSharedLinks);
    _prefs?.setBool('automaticRetry',automaticRetry);
    _prefs?.setInt('batteryFloor',batteryFloor);
    _prefs?.setBool('autoUpdateMediaEngine',autoUpdateMediaEngine);
    _prefs?.setInt('maxConcurrent',maxConcurrent);
    _prefs?.setInt('parallelChunks',parallelChunks);
    _prefs?.setInt('storageLimitMb',storageLimitMb);
    _prefs?.setDouble('fontScale',fontScale);
    unawaited(_refreshDevicePolicy());
    unawaited(_pump());
    if (newNotifications != null) {
      _notificationsAsked = false;
      _configureNotifications();
    }
    if (LanguagePreference.isSupported(newLanguage)) _configureNotifications();
    if (newAutoUpdateMediaEngine == true && _initializedMedia) unawaited(_checkMediaUpdateIfDue());
    notifyListeners();
  }

  Future<void> addConvertedFile(DownloadEntry source, String path) async {
    if(!_items.contains(source)) throw StateError('Original job was removed');
    final file=File(path);
    if(!await file.exists()) throw const FileSystemException('Converted file missing');
    final name=path.split(Platform.pathSeparator).last;
    if(_items.any((e)=>e.path==path)) return;
    final converted=DownloadEntry(id:'converted_${DateTime.now().microsecondsSinceEpoch}',
      url:source.url,name:name,kind:'direct',status:'complete',path:path,
      progress:1,addedAt:DateTime.now().millisecondsSinceEpoch);
    _items.insert(0,converted);
    notifyListeners();await _persistNow();
  }

  Future<String> exportToDownloads(DownloadEntry item) async {
    if (item.status != 'complete' || item.isPlaylist || item.path.isEmpty) {
      throw StateError('A completed single file is required');
    }
    final original = File(item.path);
    if (!await original.exists()) throw const FileSystemException('File missing');
    final tmp = await getTemporaryDirectory();
    final copy = await original.copy('${tmp.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_${UrlGuard.safeName(item.name)}');
    try {
      final output = await bd.FileDownloader().moveFileToSharedStorage(
        copy.path, bd.SharedStorage.downloads, directory: 'ADNANLOAD');
      if (output == null || output.isEmpty) throw StateError('Export failed');
      return output;
    } finally {
      if (await copy.exists()) await copy.delete();
    }
  }

  Future<void> renameFinished(DownloadEntry item, String requested) async {
    if (item.isPlaylist || item.status != 'complete') throw StateError('Only completed files can be renamed');
    final sanitized = UrlGuard.safeName(requested);
    final source = File(item.path);
    if (!await source.exists()) throw const FileSystemException('File missing');
    final separator = Platform.pathSeparator;
    final parent = source.parent.path;
    final target = File('$parent$separator$sanitized');
    if (target.path != source.path) {
      if (await target.exists()) throw const FileSystemException('Destination already exists');
      await source.rename(target.path);
    }
    item.name = sanitized; item.path = target.path;
    notifyListeners(); _persistSoon();
  }

  bool bookmarked(String url) => bookmarks.contains(url);
  void toggleBookmark(String url) {
    if (UrlGuard.validate(url) == null) return;
    if (bookmarks.contains(url)) { bookmarks.remove(url); }
    else if (bookmarks.length < 150) { bookmarks.insert(0,url); }
    _prefs?.setStringList('bookmarks', bookmarks);
    notifyListeners();
  }

  Future<void> _checkMediaUpdateIfDue() async {
    if (_updateInProgress || !autoUpdateMediaEngine) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _prefs?.getInt('lastMediaUpdateCheck') ?? 0;
    if (now - last < const Duration(days:7).inMilliseconds) return;
    _updateInProgress = true;
    try {
      final result = await YoutubeDLFlutter.instance.updateYoutubeDL(channel:UpdateChannel.stable);
      if(result.status == OperationStatus.success) {
        await _prefs?.setInt('lastMediaUpdateCheck',now);
      }
    } catch (_) { /* manual update remains available */ }
    finally { _updateInProgress = false; }
  }

  Future<void> updateMediaEngine() async {
    if (_updateInProgress) throw StateError('An update is already running');
    if (!await _ensureMedia()) throw StateError('Media engine unavailable');
    _updateInProgress = true;
    try {
      // Delegates signed-source/stable-channel checks to the extractor plugin.
      // Do not execute code from arbitrary URLs or downloaded scripts.
      final result = await YoutubeDLFlutter.instance.updateYoutubeDL(channel:UpdateChannel.stable);
      if (result.status != OperationStatus.success) {
        throw StateError(result.errorMessage ?? 'Media engine update failed');
      }
      await _prefs?.setInt('lastMediaUpdateCheck',DateTime.now().millisecondsSinceEpoch);
      _event('Stable media engine update applied');
    } finally { _updateInProgress = false; }
  }

  Future<String> downloadHealthSummary() async {
    final complete=_items.where((e)=>e.status=='complete').length;
    final failures=_items.where((e)=>e.status=='error').length;
    final pending=_items.where((e)=>e.status=='waiting').length;
    final paused=_items.where((e)=>e.status=='paused').length;
    final used=await StorageAudit.recordedBytes(_items);
    final reasons=<String,int>{};
    for(final entry in _items.where((e)=>e.status=='error')) {
      // Only stable error categories; never include raw exceptions or URLs.
      final code=entry.error;
      final safe=const {'checksumMismatch','verificationFailed','nativeQueueFailed',
        'mediaInitFailed','mediaFailedTryAgain','mediaRequestFailed','nativeMissing',
        'transferProblem'}.contains(code)?code:'other';
      reasons[safe]=(reasons[safe]??0)+1;
    }
    return 'Complete: $complete\nFailed: $failures\nWaiting: $pending\nPaused: $paused'
      '\nTracked storage: ${(used/1048576).toStringAsFixed(1)} MB'
      '\nApp limit: ${storageLimitMb==0?'Unlimited':'$storageLimitMb MB'}'
      '\nError categories: $reasons';
  }

  Future<void> _persistNow() {
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    // Retain every live job even if the history exceeds its normal limit.
    // The list of completed/failed history is capped, not the active queue.
    final active = _items.where((e) =>
      {'waiting', 'running', 'submitting', 'paused', 'verifying'}.contains(e.status));
    final activeIds = active.map((e) => e.id).toSet();
    final history = _items.where((e) => !activeIds.contains(e.id))
        .take(350).toList();
    final snapshot = <String>[
      ...active.map((e) => jsonEncode(e.toJson())),
      ...history.map((e) => jsonEncode(e.toJson())),
    ];
    // Serialize preference writes to avoid an older snapshot overwriting a
    // newer one when status callbacks arrive rapidly.
    _persistTail = _persistTail.catchError((Object _) {})
      .then((_) async { await prefs.setStringList('history', snapshot); });
    return _persistTail;
  }

  void _persistSoon() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persistNow());
    });
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _queueTimer?.cancel();
    unawaited(_persistNow());
    _directSub?.cancel(); _mediaSub?.cancel();
    _mediaErrors?.cancel();
    _connectivitySub?.cancel(); _batterySub?.cancel();
    super.dispose();
  }
}

/// Non-sensitive public metadata; do not store cookies or authentication tokens.
class MediaSnapshot {
  final String title;
  final String uploader;
  final String thumbnail;
  final int durationSeconds;
  final int formats;
  const MediaSnapshot({required this.title, required this.uploader,
    required this.thumbnail, required this.durationSeconds, required this.formats});
}
