import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/murrtube_api.dart';
import '../utils/cookie_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _blobController = TextEditingController();
  final _sessionController = TextEditingController();
  final _ageCheckController = TextEditingController();
  final _xsrfController = TextEditingController();
  final _sessionIdController = TextEditingController();
  bool _loading = false;

  Future<void> _openBrowser() async {
    final uri = Uri.parse('https://murrtube.net/sign_in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _blobController.dispose();
    _sessionController.dispose();
    _ageCheckController.dispose();
    _xsrfController.dispose();
    _sessionIdController.dispose();
    super.dispose();
  }

  String? _buildCookieString() {
    String decode(String v) {
      try {
        return Uri.decodeComponent(v);
      } catch (_) {
        return v;
      }
    }

    final blob = _blobController.text.trim();
    if (blob.isNotEmpty) {
      final parts = <String>[];
      for (final pair in blob.split(';')) {
        final eq = pair.indexOf('=');
        if (eq <= 0) continue;
        final name = pair.substring(0, eq).trim();
        final value = pair.substring(eq + 1).trim();
        if (name.isNotEmpty) {
          parts.add('$name=${decode(value)}');
        }
      }
      if (parts.isEmpty) return null;
      return parts.join('; ');
    }

    final parts = <String>[
      '_murrtube_v3_session=${decode(_sessionController.text.trim())}',
      'age_check=${decode(_ageCheckController.text.trim())}',
    ];
    final xsrf = _xsrfController.text.trim();
    if (xsrf.isNotEmpty) {
      parts.add('XSRF-TOKEN=${decode(xsrf)}');
    }
    final sessionId = _sessionIdController.text.trim();
    if (sessionId.isNotEmpty) {
      parts.add('session_id=${decode(sessionId)}');
    }
    return parts.join('; ');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveCookies() async {
    final usingBlob = _blobController.text.trim().isNotEmpty;
    if (!usingBlob) {
      if (_sessionController.text.trim().isEmpty) {
        _snack('Session cookie is required');
        return;
      }
      if (_ageCheckController.text.trim().isEmpty) {
        _snack('age_check cookie is required');
        return;
      }
    }

    setState(() => _loading = true);
    final previousCookies = MurrtubeApi.cookies;
    try {
      final cookieString = _buildCookieString();
      if (cookieString == null ||
          !cookieString.contains('_murrtube_v3_session=')) {
        _snack('Missing _murrtube_v3_session in the pasted cookies');
        return;
      }

      MurrtubeApi.setCookies(cookieString);
      // Verify the session is accepted before saving it.
      try {
        final props = await MurrtubeApi.getSettings();
        final user = (props['user'] ?? props['current_user'])
            as Map<String, dynamic>?;
        if (user == null || user['slug'] == null) {
          throw const HttpException('session rejected');
        }
      } catch (e) {
        MurrtubeApi.clearCookies();
        if (previousCookies != null) {
          MurrtubeApi.setCookies(previousCookies);
        }
        _snack('Login failed: session looks invalid or expired');
        return;
      }

      await CookieLoader.save(cookieString);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('LoginPage save error: $e');
      if (mounted) {
        _snack('Error saving cookies: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildCookieField({
    required String label,
    required String cookieName,
    required TextEditingController controller,
    bool required = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cookieName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['monospace'],
                  ),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (context, setLocalState) {
              return TextField(
                controller: controller,
                onChanged: (_) => setLocalState(() {}),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['monospace'],
                ),
                decoration: InputDecoration(
                  hintText: 'Paste value here...',
                  hintStyle: TextStyle(color: mutedColor),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 16,
                            color: mutedColor,
                          ),
                          onPressed: () {
                            controller.clear();
                            setLocalState(() {});
                          },
                        )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.login,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Log in to Murrtube',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Murrtube uses Telegram for authentication. Open the site in your browser, log in, then paste each cookie value into the fields below.',
              style: TextStyle(
                fontSize: 15,
                color: mutedColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openBrowser,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_browser, size: 20),
                    SizedBox(width: 8),
                    Text('Open murrtube.net/sign_in'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildCookieField(
              label:
                  'Fastest option: copy the full cookie string from DevTools (name=value; name=value) and paste it here.',
              cookieName: 'full cookie string',
              controller: _blobController,
            ),
            Center(
              child: Text(
                'or fill in the individual cookies',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ),
            const SizedBox(height: 14),
            _buildCookieField(
              label:
                  'This is your session token. Found in your browser cookies after logging in.',
              cookieName: '_murrtube_v3_session',
              controller: _sessionController,
              required: true,
            ),
            _buildCookieField(
              label:
                  'Verifies age check. Required to view content.',
              cookieName: 'age_check',
              controller: _ageCheckController,
              required: true,
            ),
            _buildCookieField(
              label:
                  'Security token. Needed for likes, comments, and uploads.',
              cookieName: 'XSRF-TOKEN',
              controller: _xsrfController,
              required: false,
            ),
            _buildCookieField(
              label:
                  'Session identifier. Some requests may need this.',
              cookieName: 'session_id',
              controller: _sessionIdController,
              required: false,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveCookies,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save & Connect'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tip: In your browser\'s cookie manager, copy the "Value" for each cookie name above.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
