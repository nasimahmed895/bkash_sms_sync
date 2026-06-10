import 'package:workmanager/workmanager.dart';

import '../core/app_logger.dart';
import '../core/constants.dart';
import 'service_locator.dart';
import 'sync_engine.dart';

/// WorkManager entry point. Runs in its OWN background isolate —
/// survives app kill, process death, and device reboot
/// (workmanager registers RECEIVE_BOOT_COMPLETED automatically).
@pragma('vm:entry-point')
void workManagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await setupServiceLocator();
      final allDone = await sl<SyncEngine>().syncPending();

      if (!allDone) {
        // Something is still pending — schedule the next retry using the
        // escalating schedule (30s, 1m, 5m, 15m, 30m, 1h, then 6h).
        final retryCount = (inputData?['retryCount'] as int? ?? 0) + 1;
        await BackgroundTasks.scheduleRetry(retryCount);
      }
      return true;
    } catch (e, st) {
      appLogger.e('WorkManager task failed', error: e, stackTrace: st);
      // Returning false lets WorkManager apply its own backoff as a
      // safety net on top of our explicit schedule.
      return false;
    }
  });
}

class BackgroundTasks {
  BackgroundTasks._();

  static Future<void> initialize() async {
    await Workmanager().initialize(workManagerDispatcher);

    // Safety-net periodic sync: every 6 hours until success, forever.
    // Survives reboot and app kill.
    await Workmanager().registerPeriodicTask(
      AppConstants.workManagerUniquePeriodic,
      AppConstants.periodicSyncTaskName,
      frequency: AppConstants.fallbackRetryInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Schedules an immediate one-off sync (e.g. right after an SMS arrives
  /// or when connectivity returns).
  static Future<void> scheduleImmediateSync() async {
    await Workmanager().registerOneOffTask(
      'sync-now-${DateTime.now().millisecondsSinceEpoch}',
      AppConstants.syncTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'retryCount': 0},
      existingWorkPolicy: ExistingWorkPolicy.append,
    );
  }

  /// Schedules the next retry according to the escalating schedule.
  static Future<void> scheduleRetry(int retryCount) async {
    final delay = AppConstants.retryDelayFor(retryCount);
    await Workmanager().registerOneOffTask(
      'sync-retry-$retryCount-${DateTime.now().millisecondsSinceEpoch}',
      AppConstants.syncTaskName,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'retryCount': retryCount},
      existingWorkPolicy: ExistingWorkPolicy.append,
    );
  }
}
