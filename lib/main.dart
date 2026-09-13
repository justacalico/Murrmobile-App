import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/murrtube_api.dart';
import 'utils/cookie_loader.dart';
import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';
import 'widgets/responsive_shell.dart';
import 'pages/about_page.dart';
import 'pages/age_confirmation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cookies = await CookieLoader.load();
  if (cookies != null && cookies.isNotEmpty) {
    MurrtubeApi.setCookies(cookies);
  }
  runApp(const MurrtubeApp());
}

class MurrtubeApp extends StatelessWidget {
  const MurrtubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Murrmobile',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            darkTheme: themeProvider.darkThemeData,
            themeMode: themeProvider.themeMode,
            home: const AgeCheckWrapper(),
            routes: {
              '/about/terms': (_) => const AboutPage(type: 'terms'),
              '/about/privacy': (_) => const AboutPage(type: 'privacy'),
              '/about/cookies': (_) => const AboutPage(type: 'cookies'),
              '/about/whats-new': (_) => const AboutPage(type: 'whats-new'),
            },
          );
        },
      ),
    );
  }
}

class AgeCheckWrapper extends StatefulWidget {
  const AgeCheckWrapper({super.key});

  @override
  State<AgeCheckWrapper> createState() => _AgeCheckWrapperState();
}

class _AgeCheckWrapperState extends State<AgeCheckWrapper> {
  bool _isLoading = true;
  bool _ageConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkAgeConfirmation();
  }

  Future<void> _checkAgeConfirmation() async {
    final prefs = await SharedPreferences.getInstance();
    final confirmed = prefs.getBool('age_confirmed') ?? false;
    if (mounted) {
      setState(() {
        _ageConfirmed = confirmed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_ageConfirmed) {
      return AgeConfirmationPage(
        onConfirmed: () {
          setState(() {
            _ageConfirmed = true;
          });
        },
      );
    }

    return const ResponsiveShell();
  }
}
