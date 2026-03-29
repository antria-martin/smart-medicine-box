import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import your screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_screen.dart';
import 'screens/stats_screen.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  await NotificationService().initialize();

  runApp(const SmartMedBox());
}

class SmartMedBox extends StatelessWidget {
  const SmartMedBox({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // We use 'home' for the splash, but we MUST define the routes below
      home: const SplashScreen(),
      routes: {
        '/login': (context) =>
            const LoginScreen(), // Ensure this name is correct
        '/dashboard': (context) => const DashboardScreen(),
        '/history': (context) => const LogScreen(),
        '/statistics': (context) => const StatsScreen(),
      },
    );
  }
}
