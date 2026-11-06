import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/murrtube_api.dart';
import '../utils/fullscreen_state.dart';
import '../utils/page_transitions.dart';
import '../pages/home_page.dart';
import '../pages/search_page.dart';
import '../pages/upload_page.dart';
import '../pages/notifications_page.dart';
import '../pages/settings_page.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

class ResponsiveShell extends StatefulWidget {
  final int initialIndex;
  const ResponsiveShell({super.key, this.initialIndex = 0});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  late int _selectedIndex;
  bool _wasLoggedIn = false;
  final _navigatorKeys = <String, GlobalKey<NavigatorState>>{};
  final _navObservers = <String, NavigatorObserver>{};
  final _scrollControllers = <String, ScrollController>{};

  void _onTabNavigation() {
    // Inner pushes/pops change what back should do but don't rebuild the
    // shell, so PopScope.canPop would go stale without this.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  List<NavItem> get _items {
    final base = <NavItem>[
      const NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        page: HomePage(),
      ),
      const NavItem(
        label: 'Search',
        icon: Icons.search_outlined,
        activeIcon: Icons.search_rounded,
        page: SearchPage(),
      ),
    ];
    if (MurrtubeApi.isAuthenticated) {
      base.addAll(const [
        NavItem(
          label: 'Upload',
          icon: Icons.add_circle_outline,
          activeIcon: Icons.add_circle_rounded,
          page: UploadPage(),
        ),
        NavItem(
          label: 'Activity',
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          page: NotificationsPage(),
        ),
      ]);
    }
    base.add(const NavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      page: SettingsPage(),
    ));
    return base;
  }

  GlobalKey<NavigatorState> _keyFor(NavItem item) =>
      _navigatorKeys.putIfAbsent(item.label, () => GlobalKey<NavigatorState>());

  ScrollController _scrollerFor(NavItem item) =>
      _scrollControllers.putIfAbsent(item.label, () => ScrollController());

  NavigatorObserver _observerFor(NavItem item) =>
      _navObservers.putIfAbsent(item.label, () => _NavObserver(_onTabNavigation));

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        widget.initialIndex.clamp(0, _items.length - 1);
    _wasLoggedIn = MurrtubeApi.isAuthenticated;
    MurrtubeApi.authVersion.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    MurrtubeApi.authVersion.removeListener(_onAuthChanged);
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAuthChanged() {
    final nowLoggedIn = MurrtubeApi.isAuthenticated;
    if (!mounted || nowLoggedIn == _wasLoggedIn) return;
    _wasLoggedIn = nowLoggedIn;
    // Keys are per-label so only the Upload/Activity slots are created or
    // dropped; Home/Search/Settings keep their stacks.
    final selectedLabel =
        _items[_selectedIndex.clamp(0, _items.length - 1)].label;
    setState(() {
      _selectedIndex =
          _items.indexWhere((i) => i.label == selectedLabel);
      if (_selectedIndex == -1) _selectedIndex = 0;
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      _keyFor(_items[index]).currentState?.popUntil((route) => route.isFirst);
      for (final pos in _scrollerFor(_items[index]).positions.toList()) {
        pos.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
    setState(() => _selectedIndex = index);
  }

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (var i = 0; i < _items.length && i < _digitKeys.length; i++) {
      final index = i;
      void tap() => _onItemTapped(index);
      bindings[SingleActivator(_digitKeys[i], control: true)] = tap;
      bindings[SingleActivator(_digitKeys[i], meta: true)] = tap;
    }
    return bindings;
  }

  bool _canPopRoot() {
    // A fullscreen page blocks its route's pop so back exits fullscreen
    // first; from the outside the inner navigator reports it cannot pop.
    if (fullscreenMode.value) return false;
    final items = _items;
    if (items.isEmpty) return true;
    final navigator =
        _keyFor(items[_selectedIndex.clamp(0, items.length - 1)]).currentState;
    return navigator == null || !navigator.canPop();
  }

  Widget _buildTabNavigator(NavItem item) {
    return PrimaryScrollController(
      controller: _scrollerFor(item),
      child: Navigator(
        key: _keyFor(item),
        observers: [_observerFor(item)],
        onGenerateRoute: (settings) => AppPageRoute(
          builder: (_) => item.page,
          settings: settings,
        ),
      ),
    );
  }

  Widget _buildBody(bool fullscreen) {
    final items = _items;
    final index = _selectedIndex.clamp(0, items.length - 1);
    final tabs = IndexedStack(
      index: index,
      children: items.map(_buildTabNavigator).toList(),
    );
    return PopScope(
      canPop: _canPopRoot(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _keyFor(items[index]).currentState?.maybePop();
        }
      },
      child: fullscreen ? tabs : SafeArea(child: tabs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenMode,
      builder: (context, fullscreen, _) {
        final items = _items;
        if (_selectedIndex >= items.length) {
          _selectedIndex = 0;
        }
        if (isDesktop) {
          return CallbackShortcuts(
            bindings: _shortcuts,
            child: Focus(
              autofocus: true,
              child: _DesktopLayout(
                items: items,
                selectedIndex: _selectedIndex,
                onItemTapped: _onItemTapped,
                navigatorKeys: items.map(_keyFor).toList(),
                navObservers: items.map(_observerFor).toList(),
                scrollControllers: items.map(_scrollerFor).toList(),
                chromeHidden: fullscreen,
              ),
            ),
          );
        }

        return Scaffold(
          body: _buildBody(fullscreen),
          bottomNavigationBar: fullscreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  destinations: items
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.activeIcon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<GlobalKey<NavigatorState>> navigatorKeys;
  final List<NavigatorObserver> navObservers;
  final List<ScrollController> scrollControllers;
  final bool chromeHidden;

  const _DesktopLayout({
    required this.items,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.navigatorKeys,
    required this.navObservers,
    required this.scrollControllers,
    this.chromeHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!chromeHidden) ...[
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 1200,
                minExtendedWidth: 220,
                selectedIndex: selectedIndex,
                onDestinationSelected: onItemTapped,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          semanticLabel: 'Murrmobile logo',
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 1200) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Murrmobile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                destinations: items
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1, thickness: 1),
            ],
            Expanded(
              child: PopScope(
                canPop: !chromeHidden &&
                    navigatorKeys[selectedIndex].currentState?.canPop() != true,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    navigatorKeys[selectedIndex].currentState?.maybePop();
                  }
                },
                child: IndexedStack(
                  index: selectedIndex,
                  children: items.asMap().entries.map((e) {
                    return PrimaryScrollController(
                      controller: scrollControllers[e.key],
                      child: Navigator(
                        key: navigatorKeys[e.key],
                        observers: [navObservers[e.key]],
                        onGenerateRoute: (settings) => AppPageRoute(
                          builder: (_) => e.value.page,
                          settings: settings,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavObserver extends NavigatorObserver {
  final VoidCallback onChange;

  _NavObserver(this.onChange);

  @override
  void didPush(Route route, Route? previousRoute) => onChange();

  @override
  void didPop(Route route, Route? previousRoute) => onChange();

  @override
  void didRemove(Route route, Route? previousRoute) => onChange();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onChange();
}
