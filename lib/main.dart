import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/payment_list_screen.dart';
import 'services/background_tasks.dart';
import 'services/connectivity_service.dart';
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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _connectivity = ConnectivityService();
  bool _smsReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final ok = await SmsService().start(); // permissions + listener
    if (mounted) setState(() => _smsReady = ok);
    _connectivity.start(); // instant flush when internet returns
  }

  @override
  void dispose() {
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
