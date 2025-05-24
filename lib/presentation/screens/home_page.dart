import 'package:flutter/material.dart';
import 'package:news_lens/presentation/screens/tabs/cronology_tab/cronology_tab.dart';
import 'package:news_lens/presentation/screens/tabs/home_tab/home_tab.dart';
import 'package:news_lens/presentation/screens/tabs/settings_tab/settings_tab.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;

  static final List<Widget> _pages = [
    const CronologyTab(),
    const HomeTab(),
    const SettingsTab(),
    
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness== Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items:  [
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_toggle_off),
              label: l10n.chronology,
            ),
             BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: l10n.home,
            ),
             BottomNavigationBarItem(
              icon: const Icon(Icons.settings),
              label: l10n.settings,
            ),
             
            
          ],
          selectedItemColor: isDarkMode? Colors.white : Colors.black,
        ),
    );
  }
}



