import 'package:flutter/material.dart';
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
  List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  List<NavigatorObserver> _navObservers = [];

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

  void _updateNavigatorKeys() {
    final count = _items.length;
    if (_navigatorKeys.length != count) {
      _navigatorKeys = List.generate(count, (_) => GlobalKey<NavigatorState>());
      _navObservers = List.generate(count, (_) => _NavObserver(_onTabNavigation));
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _wasLoggedIn = MurrtubeApi.isAuthenticated;
    _updateNavigatorKeys();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowLoggedIn = MurrtubeApi.isAuthenticated;
    if (nowLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = nowLoggedIn;
      if (_selectedIndex >= _items.length) {
        _selectedIndex = 0;
      }
      _updateNavigatorKeys();
      setState(() {});
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _selectedIndex = index);
  }

  bool _canPopRoot() {
    // A fullscreen page blocks its route's pop so back exits fullscreen
    // first; from the outside the inner navigator reports it cannot pop.
    if (fullscreenMode.value) return false;
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    return navigator == null || !navigator.canPop();
  }

  Widget _buildTabNavigator(int index, Widget page) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_navObservers[index]],
      onGenerateRoute: (settings) => AppPageRoute(
        builder: (_) => page,
        settings: settings,
      ),
    );
  }

  Widget _buildBody(bool fullscreen) {
    final tabs = IndexedStack(
      index: _selectedIndex,
      children: _items.asMap().entries.map((e) {
        return _buildTabNavigator(e.key, e.value.page);
      }).toList(),
    );
    return PopScope(
      canPop: _canPopRoot(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigatorKeys[_selectedIndex].currentState?.maybePop();
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
        // Rebuilds that bypass didChangeDependencies (like the fullscreen
        // listener) can leave the index past a shrunken tab list.
        if (_selectedIndex >= _items.length) {
          _selectedIndex = 0;
          _updateNavigatorKeys();
        }
        if (isDesktop) {
          return _DesktopLayout(
            items: _items,
            selectedIndex: _selectedIndex,
            onItemTapped: _onItemTapped,
            navigatorKeys: _navigatorKeys,
            navObservers: _navObservers,
            chromeHidden: fullscreen,
          );
        }

        return Scaffold(
          body: _buildBody(fullscreen),
          bottomNavigationBar: fullscreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  destinations: _items
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
  final bool chromeHidden;

  const _DesktopLayout({
    required this.items,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.navigatorKeys,
    required this.navObservers,
    this.chromeHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          if (!chromeHidden) ...[
            NavigationRail(
              extended: true,
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
                      ),
                    ),
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
                  return Navigator(
                    key: navigatorKeys[e.key],
                    observers: [navObservers[e.key]],
                    onGenerateRoute: (settings) => AppPageRoute(
                      builder: (_) => e.value.page,
                      settings: settings,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
