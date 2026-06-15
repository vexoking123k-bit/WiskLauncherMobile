import 'package:flutter/material.dart';

import 'pages/accounts/accounts_page.dart';
import 'pages/downloads/downloads_page.dart';
import 'pages/home/home_page.dart';
import 'pages/java/java_page.dart';
import 'pages/logs/logs_page.dart';
import 'pages/mods/mods_page.dart';
import 'pages/profiles/profiles_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/versions/versions_page.dart';
import 'theme/app_theme.dart';

enum NavTab { home, versions, accounts, profiles, mods, java, downloads, logs, settings }

class _NavItem {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final Widget page;
  const _NavItem(this.icon, this.iconActive, this.label, this.page);
}

const _items = <_NavItem>[
  _NavItem(Icons.home_outlined,           Icons.home_rounded,           'Home',     HomePage()),
  _NavItem(Icons.layers_outlined,         Icons.layers_rounded,         'Versions', VersionsPage()),
  _NavItem(Icons.person_outline_rounded,  Icons.person_rounded,         'Accounts', AccountsPage()),
  _NavItem(Icons.folder_special_outlined, Icons.folder_special_rounded, 'Profiles', ProfilesPage()),
  _NavItem(Icons.extension_outlined,      Icons.extension_rounded,      'Loaders',  ModsPage()),
  _NavItem(Icons.coffee_outlined,         Icons.coffee_rounded,         'Java',     JavaPage()),
  _NavItem(Icons.download_outlined,       Icons.download_rounded,       'Downloads',DownloadsPage()),
  _NavItem(Icons.subject_outlined,        Icons.subject_rounded,        'Logs',     LogsPage()),
  _NavItem(Icons.settings_outlined,       Icons.settings_rounded,       'Settings', SettingsPage()),
];

/// Exposes the shell's `goTo(tab)` to descendants so any page can jump tabs.
class AppShellScope extends InheritedWidget {
  final void Function(NavTab) goTo;
  const AppShellScope({super.key, required this.goTo, required super.child});

  static AppShellScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(s != null, 'AppShellScope missing — wrap with AppShell');
    return s!;
  }

  @override
  bool updateShouldNotify(AppShellScope old) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  // Track which tabs have ever been visited. We only mount their widget
  // subtree after first visit (big startup win — at boot we only build the
  // Home page, not all nine). Once mounted, the widget stays alive in the
  // IndexedStack so its state and provider subscriptions are preserved.
  final Set<int> _visited = {0};

  void _goTo(NavTab tab) {
    setState(() {
      _index = tab.index;
      _visited.add(tab.index);
    });
  }

  Widget _bodyStack() => IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _items.length; i++)
            _visited.contains(i)
                ? _items[i].page
                : const SizedBox.shrink(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    final body = _bodyStack();

    if (wide) {
      return AppShellScope(
        goTo: _goTo,
        child: Scaffold(
          body: Row(children: [
            NavigationRail(
              backgroundColor: AppTheme.bgPanel,
              selectedIndex: _index,
              onDestinationSelected: (i) => _goTo(NavTab.values[i]),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _items.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_items[i].icon),
                    selectedIcon: Icon(_items[i].iconActive),
                    label: Text(_items[i].label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ]),
        ),
      );
    }

    // Phones: bottom nav with the 5 most important tabs; the rest live behind
    // a "More" sheet so the bar isn't cramped.
    const primary = [NavTab.home, NavTab.profiles, NavTab.accounts, NavTab.versions, NavTab.logs];
    final selectedPrimary = primary.indexOf(NavTab.values[_index]);
    return AppShellScope(
      goTo: _goTo,
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppTheme.bgPanel,
          selectedIndex: selectedPrimary >= 0 ? selectedPrimary : primary.length,
          onDestinationSelected: (i) {
            if (i < primary.length) {
              _goTo(primary[i]);
            } else {
              _showMoreSheet(context);
            }
          },
          destinations: [
            for (final tab in primary)
              NavigationDestination(
                icon: Icon(_items[tab.index].icon),
                selectedIcon: Icon(_items[tab.index].iconActive),
                label: _items[tab.index].label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    const extras = [NavTab.mods, NavTab.java, NavTab.downloads, NavTab.settings];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgPanel,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final tab in extras)
            ListTile(
              leading: Icon(_items[tab.index].iconActive),
              title: Text(_items[tab.index].label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); _goTo(tab); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

}
