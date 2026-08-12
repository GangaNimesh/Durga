import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/new_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with project credentials
  await SupabaseService.instance.init(
    supabaseUrl: 'https://qfkmeqbtodaeqhaagryu.supabase.co',
    supabaseAnonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFma21lcWJ0b2RhZXFoYWFncnl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1Mzk0MjIsImV4cCI6MjEwMjExNTQyMn0.cF13lEhSKjIolYQeri4E9NttUoHVyjgh7H7Gw3jb_QE',
  );

  runApp(const DurgaApp());
}

class DurgaApp extends StatelessWidget {
  const DurgaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppEntryGate(),
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