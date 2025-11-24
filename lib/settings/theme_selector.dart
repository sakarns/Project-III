import 'package:flutter/material.dart';
import 'package:minimills/core/theme_controller.dart';
import 'package:radio_group_v2/radio_group_v2.dart' as rg;

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  ThemeMode _selectedMode = ThemeController.themeMode.value;

  void _onThemeChanged(ThemeMode? mode) {
    if (mode == null) return;
    setState(() => _selectedMode = mode);
    ThemeController.setTheme(mode);
  }

  @override
  Widget build(BuildContext context) {
    return rg.RadioGroup<ThemeMode>(
      values: ThemeMode.values,
      orientation: rg.RadioGroupOrientation.vertical,
      indexOfDefault: ThemeMode.values.indexOf(_selectedMode),
      labelBuilder: (mode) {
        switch (mode) {
          case ThemeMode.system:
            return const Text('System Default');
          case ThemeMode.light:
            return const Text('Light');
          case ThemeMode.dark:
            return const Text('Dark');
        }
      },
      onChanged: _onThemeChanged,
    );
  }
}
