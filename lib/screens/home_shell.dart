import 'package:flutter/material.dart';

import '../theme.dart';
import 'games_screen.dart';
import 'nearby_screen.dart';
import 'party_screen.dart';
import 'plan_screen.dart';

/// Bottom navigation: Plan · Nearby · Games · Party.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const _tabs = [
    (Icons.calendar_month_outlined, 'Plan'),
    (Icons.place_outlined, 'Nearby'),
    (Icons.sports_esports_outlined, 'Games'),
    (Icons.celebration_outlined, 'Party'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = index == 3;
    final pages = [
      PlanScreen(onNavigate: (i) => setState(() => index = i)),
      const NearbyScreen(),
      const GamesScreen(),
      const PartyScreen(),
    ];

    return Scaffold(
      backgroundColor: dark ? HC.ink : HC.ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF110F20) : HC.card,
          border: Border(top: BorderSide(color: dark ? const Color(0x14FFFFFF) : HC.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => index = i),
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_tabs[i].$1, color: _color(i, dark)),
                            const SizedBox(height: 4),
                            Text(_tabs[i].$2, style: body(11, color: _color(i, dark), weight: i == index ? FontWeight.w600 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _color(int i, bool dark) {
    if (i == index) return dark ? HC.lime : HC.violet;
    return dark ? HC.nightMuted : HC.muted;
  }
}
