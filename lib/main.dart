import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'services/solo_trip_service.dart';
import 'services/widget_service.dart';
import 'services/safety_notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/new_home_screen.dart';
import 'screens/fake_call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables safely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file: $e");
  }

  // Initialize Supabase with project credentials
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://qfkmeqbtodaeqhaagryu.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFma21lcWJ0b2RhZXFoYWFncnl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1Mzk0MjIsImV4cCI6MjEwMjExNTQyMn0.cF13lEhSKjIolYQeri4E9NttUoHVyjgh7H7Gw3jb_QE';

  try {
    await SupabaseService.instance.init(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }
  
  try {
    await SoloTripService.instance.init();
  } catch (e) {
    debugPrint("SoloTripService init error: $e");
  }

  // Initialize the home-screen widget bridge
  try {
    await WidgetService.instance.init();
  } catch (e) {
    debugPrint("WidgetService init error: $e");
  }

  // Initialize lock screen safety notification widget
  try {
    await SafetyNotificationService.instance.init();
  } catch (e) {
    debugPrint("SafetyNotificationService init error: $e");
  }

  runApp(const DurgaApp());
}

class DurgaApp extends StatelessWidget {
  const DurgaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: WidgetService.instance.navigatorKey,
        home: const AppEntryGate(),
        routes: {
          '/fake-call': (_) => const FakeCallScreen(),
          // /record and /voice are handled via onGenerateRoute below
          // because they need the home screen context.
        },
        onGenerateRoute: (settings) {
          // Deep-link routes from the widget that aren't simple pushes.
          // /record and /voice are handled by navigating to NewHomeScreen
          // with an argument that triggers the action on mount.
          if (settings.name == '/record' || settings.name == '/voice') {
            return MaterialPageRoute(
              builder: (_) => NewHomeScreen(widgetAction: settings.name),
            );
          }
          return null;
        },
      ),
    );
  }
}

/// Top-level gate: checks onboarding completion first.
///
/// Flow: OnboardingScreen (first launch only) → BottomNav (homepage)
class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool _resolved = false;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final complete = await OnboardingScreen.isComplete();
    if (mounted) {
      setState(() {
        _onboardingComplete = complete;
        _resolved = true;
      });
    }

    // If launched from widget tap, navigate to the pending route
    if (_onboardingComplete) {
      final pending = WidgetService.instance.pendingRoute;
      if (pending != null) {
        WidgetService.instance.pendingRoute = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (pending == '/fake-call') {
            Navigator.of(context).pushNamed(pending);
          } else {
            WidgetService.instance.handleAction(pending);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      // Brief splash while checking SharedPreferences
      return const Scaffold(
        backgroundColor: Color(0xFF1A0A14),
        body: SizedBox.shrink(),
      );
    }

    if (!_onboardingComplete) {
      return const OnboardingScreen();
    }

    return const NewHomeScreen();
  }
}