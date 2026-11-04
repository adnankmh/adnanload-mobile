import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/url_guard.dart';

/// Android-only, best-effort one-off scheduling for DIRECT FILE downloads.
/// Android WorkManager does not promise execution at the exact requested minute.
const scheduledDirectTaskName = 'adnanload.scheduled.direct.v1';

String scheduledWorkId(String id) => 'adnanload.direct.$id';

/// A scheduled transfer must never begin before its requested wall-clock time.
/// WorkManager may invoke a job early after clock changes or OS rescheduling.
/// Invalid timestamps are discarded rather than retried forever.
enum ScheduledStartDecision { discard, retryLater, start }

ScheduledStartDecision scheduledStartDecision(int scheduledAt, int nowMillis) {
  if (scheduledAt <= 0) return ScheduledStartDecision.discard;
  if (scheduledAt > nowMillis) return ScheduledStartDecision.retryLater;
  return ScheduledStartDecision.start;
}

@pragma('vm:entry-point')
void adnanloadScheduleDispatcher() {
  Workmanager().executeTask((name, inputData) async {
    if (name != scheduledDirectTaskName || inputData == null) return true;
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final id = inputData['id'];
    final rawUrl = inputData['url'];
    final fileName = inputData['name'];
    final scheduledAt = inputData['scheduledAt'];
    if (id is! String || id.isEmpty || rawUrl is! String ||
        fileName is! String || scheduledAt is! int) return true;
    final timing = scheduledStartDecision(
      scheduledAt, DateTime.now().millisecondsSinceEpoch,
    );
    if (timing == ScheduledStartDecision.discard) return true;
    if (timing == ScheduledStartDecision.retryLater) {
      return false; // WorkManager retries; never enqueue before the chosen time.
    }
    final url = UrlGuard.validate(rawUrl);
    if (url == null || UrlGuard.safeName(fileName) != fileName) {
      return false; // preserve existing retry behavior for invalid payloads
    }
    try {
      final downloader = bd.FileDownloader();
      await downloader.start(autoCleanDatabase: false);
      // The native transfer database is our idempotency barrier.
      if (await downloader.taskForId(id) != null) return true;
      downloader.configureNotification(
        running: const bd.TaskNotification('ADNANLOAD · Downloading', '{filename}'),
        complete: const bd.TaskNotification('ADNANLOAD · Complete', '{filename}'),
        error: const bd.TaskNotification('ADNANLOAD · Failed', '{filename}'),
        progressBar: true,
      );
      final task = bd.DownloadTask(
        taskId: id,
        url: url.toString(),
        filename: fileName,
        directory: 'ADNANLOAD',
        baseDirectory: bd.BaseDirectory.applicationDocuments,
        allowPause: true,
        retries: 5,
        requiresWiFi: inputData['wifiOnly'] == true,
        priority: (inputData['priority'] is int)
            ? (inputData['priority'] as int).clamp(0, 10).toInt() : 5,
        updates: bd.Updates.statusAndProgress,
        transferHints: const {bd.TransferHint.largeFile},
      );
      return await downloader.enqueue(task);
    } catch (_) {
      // WorkManager may retry; the native task id prevents duplicate enqueues.
      return false;
    }
  });
}

class AndroidScheduleService {
  AndroidScheduleService._();
  static bool initialized = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid || initialized) return;
    await Workmanager().initialize(adnanloadScheduleDispatcher);
    initialized = true;
  }

  static Future<bool> register({
    required String id,
    required String url,
    required String name,
    required DateTime when,
    required bool wifiOnly,
    required bool chargingOnly,
    required int priority,
  }) async {
    if (!Platform.isAndroid || !initialized) return false;
    if (UrlGuard.validate(url) == null || id.isEmpty ||
        UrlGuard.safeName(name) != name || url.length > 3500) return false;
    final delay = when.difference(DateTime.now());
    if (delay <= Duration.zero) return false;
    try {
      await Workmanager().registerOneOffTask(
        scheduledWorkId(id), scheduledDirectTaskName,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        initialDelay: delay,
        constraints: Constraints(networkType:
            wifiOnly ? NetworkType.unmetered : NetworkType.connected,
            requiresCharging: chargingOnly),
        inputData: {
          'id': id,
          'url': url,
          'name': name,
          'scheduledAt': when.millisecondsSinceEpoch,
          'wifiOnly': wifiOnly,
          'priority': priority,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(String id) async {
    if (!initialized || !Platform.isAndroid) return;
    try { await Workmanager().cancelByUniqueName(scheduledWorkId(id)); }
    catch (_) { /* native scheduler might already have started */ }
  }
}
