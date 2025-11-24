import 'package:flutter/material.dart';

class ThemeController {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }
}
