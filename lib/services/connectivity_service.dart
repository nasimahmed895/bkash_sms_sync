import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/app_logger.dart';
import 'background_tasks.dart';
import 'service_locator.dart';
import 'sync_engine.dart';

/// Internet-recovery watcher. The moment connectivity returns, all
/// pending_sync records are loaded and submitted one by one.
///
/// (WorkManager's NetworkType.connected constraint provides the same
/// guarantee while the app is killed; this service makes recovery
/// instant while the app is alive.)
class ConnectivityService {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) return;

      appLogger.i('Internet restored — flushing pending payments.');
      final allDone = await sl<SyncEngine>().syncPending();
      if (!allDone) {
        await BackgroundTasks.scheduleRetry(0);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
