import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/murrtube_api.dart';
import '../utils/cookie_loader.dart';
import '../utils/app_preferences.dart';
import '../utils/page_transitions.dart';
import '../providers/theme_provider.dart';
import '../providers/navigation_provider.dart';
import 'login_page.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _props;
  bool _loading = true;
  bool _wasLoggedIn = false;
  String _videoQuality = 'auto';

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = MurrtubeApi.isAuthenticated;
    _loadLocal();
    _load();
  }

  Future<void> _loadLocal() async {
    final quality = await AppPreferences.getVideoQuality();
    if (mounted) {
      setState(() => _videoQuality = quality);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowLoggedIn = MurrtubeApi.isAuthenticated;
    if (nowLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = nowLoggedIn;
      _load();
    }
  }

  Future<void> _load() async {
    if (!MurrtubeApi.isAuthenticated) {
      setState(() {
        _props = null;
        _loading = false;
      });
      return;
    }
    try {
      final props = await MurrtubeApi.getSettings();
      final user = props['current_user'] as Map<String, dynamic>?;
      if (user != null && user['slug'] != null) {
        MurrtubeApi.currentUserSlug = user['slug'] as String;
      }
      setState(() {
        _props = props;
        _loading = false;
      });
    } catch (e) {
      debugPrint('SettingsPage error: $e');
      setState(() {
        _props = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _props?['user'] as Map<String, dynamic>?;
    final serverQuality = _props?['video_quality_options'] as List<dynamic>? ?? [];

    final themes = [
      {'name': 'Auto (System)', 'value': 'auto'},
      {'name': 'Dark', 'value': 'dark'},
      {'name': 'Light', 'value': 'light'},
      {'name': 'AMOLED', 'value': 'amoled'},
    ];
    final qualityOptions = serverQuality.isNotEmpty
        ? serverQuality
        : [
            {'label': 'Auto', 'value': 'auto'},
            {'label': '1080p', 'value': '1080p'},
            {'label': '720p', 'value': '720p'},
            {'label': '480p', 'value': '480p'},
            {'label': '360p', 'value': '360p'},
          ];

    return Scaffold(
      body: _loading
          ? Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                if (user != null) ...[
                  _buildCard(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (user['slug'] != null) {
                              pushPage(
                                context,
                                builder: (_) => ProfilePage(
                                  slug: user['slug'] as String,
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              ClipOval(
                                child: user['avatar_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: user['avatar_url'],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.person,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] ?? 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (user['slug'] != null)
                                    Text(
                                      '@${user['slug']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: 12),
                        _buildActionTile(
                          icon: Icons.logout,
                          label: 'Log Out',
                          iconColor: Theme.of(context).colorScheme.error,
                          onTap: () async {
                            MurrtubeApi.clearCookies();
                            await CookieLoader.clear();
                            debugPrint('Logged out');
                            if (mounted) _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  _buildCard(
                    child: _buildActionTile(
                      icon: Icons.login,
                      label: 'Log In',
                      subtitle: 'For uploads, comments, and notifications',
                      iconColor: Theme.of(context).colorScheme.primary,
                      onTap: () async {
                        final result = await pushPage<bool>(
                          context,
                          builder: (_) => const LoginPage(),
                        );
                        if (result == true && mounted) {
                          _load();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionLabel('Appearance'),
                _buildCard(
                  child: Builder(
                    builder: (context) {
                      final themeProvider = context.watch<ThemeProvider>();
                      final current = themeProvider.currentTheme;
                      return Column(
                        children: [
                          _buildActionTile(
                            icon: Icons.palette_outlined,
                            label: 'Theme',
                            subtitle: current[0].toUpperCase() + current.substring(1),
                            onTap: () => _showSelectionSheet(
                              title: 'Select Theme',
                              options: themes.map((t) {
                                final name = t['name'] ?? 'Theme';
                                final value = t['value'] ?? name.toLowerCase();
                                return _SelectionOption(label: name, value: value);
                              }).toList(),
                              selected: current,
                              onSelect: (value) => themeProvider.setTheme(value),
                            ),
                            showDivider: true,
                          ),
                          _buildActionTile(
                            icon: Icons.view_sidebar_outlined,
                            label: 'Small Screen Navigation',
                            subtitle: _getNavigationModeLabel(context),
                            onTap: () => _showSelectionSheet(
                              title: 'Select Small Screen Navigation',
                              options: const [
                                _SelectionOption(label: 'Collapsed Sidebar', value: 'collapsed_sidebar'),
                                _SelectionOption(label: 'Bottom Bar', value: 'bottom_bar'),
                              ],
                              selected: context.read<NavigationProvider>().navigationMode,
                              onSelect: (value) async {
                                await context.read<NavigationProvider>().setNavigationMode(value);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Video Quality'),
                _buildCard(
                  child: _buildActionTile(
                    icon: Icons.high_quality_outlined,
                    label: 'Preferred Quality',
                    subtitle: _videoQuality[0].toUpperCase() + _videoQuality.substring(1),
                    onTap: () => _showSelectionSheet(
                      title: 'Select Video Quality',
                      options: qualityOptions.map((q) {
                        final isMap = q is Map<String, dynamic>;
                        final label = isMap ? (q['label'] ?? q.toString()) : q.toString();
                        final value = isMap ? (q['value'] ?? label) : q.toString();
                        return _SelectionOption(label: label, value: value);
                      }).toList(),
                      selected: _videoQuality,
                      onSelect: (value) async {
                        await AppPreferences.setVideoQuality(value);
                        setState(() => _videoQuality = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Legal - Murrtube.net'),
                _buildCard(
                  child: Column(
                    children: [
                      _buildActionTile(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        onTap: () => launchUrl(
                          Uri.parse('https://murrtube.net/about/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                        showDivider: true,
                      ),
                      _buildActionTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => launchUrl(
                          Uri.parse('https://murrtube.net/about/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                        showDivider: true,
                      ),
                      _buildActionTile(
                        icon: Icons.cookie_outlined,
                        label: 'Cookie Policy',
                        onTap: () => launchUrl(
                          Uri.parse('https://murrtube.net/about/cookies'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  _SectionLabel('Debug'),
                  _buildCard(
                    child: _buildActionTile(
                      icon: Icons.bug_report_outlined,
                      label: 'Reset Age Confirmation',
                      iconColor: Theme.of(context).colorScheme.error,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('age_confirmed');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Age confirmation reset. Restart app to test again.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
    bool showDivider = false,
  }) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? mutedColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<_SelectionOption> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final isActive = selected == opt.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isActive ? colorScheme.primary : mutedColor,
                      ),
                      title: Text(
                        opt.label,
                        style: TextStyle(
                          color: isActive ? colorScheme.onSurface : mutedColor,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        onSelect(opt.value);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _SectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getNavigationModeLabel(BuildContext context) {
    final navigationMode = context.watch<NavigationProvider>().navigationMode;
    switch (navigationMode) {
      case 'collapsed_sidebar':
        return 'Collapsed Sidebar';
      case 'bottom_bar':
        return 'Bottom Bar';
      default:
        return 'Collapsed Sidebar';
    }
  }
}

class _SelectionOption {
  final String label;
  final String value;
  const _SelectionOption({required this.label, required this.value});
}
