import 'package:flutter/material.dart';

/// Design tokens from design.md — rural shopkeeper UI
class AppColors {
  // Background (ledger-paper)
  static const background = Color(0xFFFAF6EF);

  // Surface (cards/inputs)
  static const surface = Color(0xFFFFFFFF);

  // Ink (primary text)
  static const inkPrimary = Color(0xFF2B2620);

  // Ink soft (secondary text)
  static const inkSoft = Color(0xFF6B6153);

  // Primary (buttons/brand) — khata-green
  static const primary = Color(0xFF0F6B5C);
  static const primaryDark = Color(0xFF0B4F44);
  static const primarySoft = Color(0xFFE3F0EC);

  // Accent (highlights) — marigold
  static const accent = Color(0xFFF2A93B);
  static const accentSoft = Color(0xFFFCEBCB);

  // Danger (errors)
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFBE4E4);

  // Success
  static const success = Color(0xFF2F9E44);

  // Border
  static const border = Color(0xFFE7DFD0);

  /// Avatar colors — deterministic by name hash
  static const List<Color> avatarPalette = [
    Color(0xFF0F6B5C), // khata-green
    Color(0xFFB5533C), // rust
    Color(0xFF3C6E9C), // slate blue
    Color(0xFF8A5FB0), // lavender
    Color(0xFFB08900), // ochre
  ];

  /// Get a deterministic avatar color from a name
  static Color avatarColorForName(String name) {
    if (name.isEmpty) return avatarPalette[0];
    int hash = name.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0xffffffff);
    return avatarPalette[hash % avatarPalette.length];
  }
}
