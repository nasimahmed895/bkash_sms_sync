import 'package:get_it/get_it.dart';

import '../data/local/payment_db.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/payment_repository_impl.dart';
import '../domain/repositories/payment_repository.dart';
import 'sync_engine.dart';

final GetIt sl = GetIt.instance;

/// Registers all dependencies. Safe to call from ANY isolate
/// (UI, SMS background isolate, WorkManager isolate) — it is idempotent.
Future<void> setupServiceLocator() async {
  if (sl.isRegistered<PaymentRepository>()) return;

  sl.registerLazySingleton<PaymentDb>(() => PaymentDb());
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<PaymentRepository>(
      () => PaymentRepositoryImpl(sl<PaymentDb>(), sl<ApiClient>()));
  sl.registerLazySingleton<SyncEngine>(
      () => SyncEngine(sl<PaymentRepository>(), sl<ApiClient>()));
}
