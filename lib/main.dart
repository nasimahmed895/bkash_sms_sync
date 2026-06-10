import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/payment_list_screen.dart';
import 'services/background_tasks.dart';
import 'services/connectivity_service.dart';
import 'services/notification_capture_service.dart';
import 'services/service_locator.dart';
import 'services/sms_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();
  await BackgroundTasks.initialize(); // WorkManager + 6h periodic safety net

  runApp(const ProviderScope(child: BkashSyncApp()));
}

class BkashSyncApp extends StatelessWidget {
  const BkashSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bKash Payment Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE2136E), // bKash pink
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _connectivity = ConnectivityService();
  final _notifService = NotificationCaptureService();
  bool _smsReady = false;
  bool _notifReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final smsOk = await SmsService().start();
    final notifOk = await _notifService.isAccessGranted();
    if (notifOk) _notifService.start();
    if (mounted) setState(() { _smsReady = smsOk; _notifReady = notifOk; });
    _connectivity.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_notifReady) {
      _notifService.isAccessGranted().then((ok) {
        if (ok && mounted) {
          _notifService.start();
          setState(() => _notifReady = true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_smsReady)
            MaterialBanner(
              backgroundColor: Colors.red.shade50,
              content: const Text(
                  'SMS permission not granted — payments cannot be captured.'),
              actions: [
                TextButton(
                  onPressed: _bootstrap,
                  child: const Text('Grant'),
                ),
              ],
            ),
          if (!_notifReady)
            MaterialBanner(
              backgroundColor: Colors.orange.shade50,
              content: const Text(
                  'Notification access not enabled — enable for dual-capture fallback.'),
              actions: [
                TextButton(
                  onPressed: _notifService.openAccessSettings,
                  child: const Text('Enable'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                DashboardScreen(),
                PaymentListScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Payments'),
        ],
      ),
    );
  }
}
