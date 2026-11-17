import 'package:material_ui/material_ui.dart';

import '../../core/rafel_theme.dart';
import '../screens/occasions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/today_screen.dart';

/// One place for the muted tone that was previously repeated as
/// `surfaceVariant.withValues(alpha: 0.72)` everywhere.
extension on RafelThemeData {
  Color get muted => surfaceVariant.withValues(alpha: 0.72);
}

// ─────────────────────────────────────────────────────────────────────────────
// Home shell — bottom navigation container
// ─────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openOccasions() => setState(() => _index = 1);
  void _openSettings() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);

    // TickerMode mutes the hidden tabs' animation controllers (the countdown
    // ticker and pulsing dot) so they don't burn frames while offstage.
    final screens = <Widget>[
      TickerMode(
        enabled: _index == 0,
        child: TodayScreen(
          onOpenOccasions: _openOccasions,
          onOpenSettings: _openSettings,
        ),
      ),
      TickerMode(enabled: _index == 1, child: const OccasionsScreen()),
      TickerMode(enabled: _index == 2, child: const SettingsScreen()),
    ];

    return Scaffold(
      backgroundColor: theme.background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.surface,
        selectedItemColor: theme.active,
        unselectedItemColor: theme.muted,
        elevation: 0,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Occasions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
