import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/murrtube_api.dart';
import '../utils/page_transitions.dart';
import '../pages/home_page.dart';
import '../pages/search_page.dart';
import '../pages/upload_page.dart';
import '../pages/notifications_page.dart';
import '../pages/settings_page.dart';
import '../providers/navigation_provider.dart';

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
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    return navigator == null || !navigator.canPop();
  }

  Widget _buildTabNavigator(int index, Widget page) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => AppPageRoute(
        builder: (_) => page,
        settings: settings,
      ),
    );
  }

  Widget _buildBody() {
    return PopScope(
      canPop: _canPopRoot(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigatorKeys[_selectedIndex].currentState?.pop();
        }
      },
      child: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _items.asMap().entries.map((e) {
            return _buildTabNavigator(e.key, e.value.page);
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final navigationProvider = context.watch<NavigationProvider>();
    final navigationMode = navigationProvider.navigationMode;

    if (isDesktop) {
      return _DesktopLayout(
        items: _items,
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        navigatorKeys: _navigatorKeys,
        isCollapsed: false,
        onToggleCollapse: () {}, // coverage:ignore-line
        canExpand: false,
      );
    }

    if (navigationMode == 'collapsed_sidebar') {
      return _DesktopLayout(
        items: _items,
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        navigatorKeys: _navigatorKeys,
        isCollapsed: true,
        onToggleCollapse: () {}, // coverage:ignore-line
        canExpand: false,
      );
    }

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
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
  }
}

class _DesktopLayout extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<GlobalKey<NavigatorState>> navigatorKeys;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool canExpand;

  const _DesktopLayout({
    required this.items,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.navigatorKeys,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.canExpand = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: !isCollapsed,
            minExtendedWidth: 220,
            selectedIndex: selectedIndex,
            onDestinationSelected: onItemTapped,
            leading: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment:
                    isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
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
                  if (!isCollapsed) ...[
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
            // coverage:ignore-start
            // canExpand is always false at both call sites, so the collapse
            // button never builds.
            trailing: canExpand
                ? IconButton(
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      isCollapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                    ),
                  )
                : null,
            // coverage:ignore-end
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
          Expanded(
            child: PopScope(
              canPop: navigatorKeys[selectedIndex].currentState?.canPop() != true,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) {
                  navigatorKeys[selectedIndex].currentState?.pop();
                }
              },
              child: IndexedStack(
                index: selectedIndex,
                children: items.asMap().entries.map((e) {
                  return Navigator(
                    key: navigatorKeys[e.key],
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
