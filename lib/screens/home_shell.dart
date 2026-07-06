import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'translate_screen.dart';
import 'voice_room_screen.dart';
import 'paywall_screen.dart';

/// الهيكل الرئيسي مع شريط التنقل السفلي
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final screens = [
      const TranslateScreen(),
      const VoiceRoomScreen(),
      const PaywallScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.forum_rounded, 'ترجمة'),
                _navItem(1, Icons.headset_mic_rounded, 'غرفة صوتية'),
                _navItem(2, Icons.workspace_premium_rounded,
                    app.subscribed ? 'اشتراكك' : 'اشتراك'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = _index == i;
    return GestureDetector(
      onTap: () => setState(() => _index = i),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: active ? AppColors.teal : AppColors.faint, size: 22),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: active ? AppColors.teal : AppColors.faint,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400)),
        ],
      ),
    );
  }
}
