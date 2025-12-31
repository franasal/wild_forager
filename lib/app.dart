import 'package:flutter/material.dart';
import 'package:wild_forager/ui/screens/home_screen.dart';
import 'theme.dart';
import 'services/cache_service.dart';

class WildForagerApp extends StatefulWidget {
  const WildForagerApp({super.key});

  @override
  State<WildForagerApp> createState() => _WildForagerAppState();
}

class _WildForagerAppState extends State<WildForagerApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await CacheService.getThemeMode();
    setState(() => _mode = saved);
  }

  Future<void> _toggleTheme() async {
    final next = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    setState(() => _mode = next);
    await CacheService.setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wild Forager',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: HomeScreen(onToggleTheme: _toggleTheme, themeMode: _mode),
      debugShowCheckedModeBanner: false,
    );
  }
}
