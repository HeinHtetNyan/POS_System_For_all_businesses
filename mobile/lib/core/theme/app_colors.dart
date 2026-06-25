import 'package:flutter/material.dart';

class AppColors {
  // Brand (amber – same in both modes)
  static const Color primary     = Color(0xFFF59E0B); // amber-500
  static const Color primaryDark = Color(0xFFD97706); // amber-600
  static const Color primaryFg   = Color(0xFF000000); // text ON amber bg

  // Surfaces – dark (zinc palette)
  static const Color background    = Color(0xFF09090B); // zinc-950
  static const Color surface       = Color(0xFF18181B); // zinc-900
  static const Color surfaceVariant= Color(0xFF27272A); // zinc-800
  static const Color divider       = Color(0xFF3F3F46); // zinc-700
  static const Color border        = Color(0xFF52525B); // zinc-600

  // Text
  static const Color textPrimary   = Color(0xFFFAFAFA); // zinc-50
  static const Color textSecondary = Color(0xFFA1A1AA); // zinc-400
  static const Color textDisabled  = Color(0xFF52525B); // zinc-600
  static const Color textOnPrimary = Color(0xFF000000); // black on amber

  // Semantic
  static const Color success      = Color(0xFF4ADE80); // green-400
  static const Color successLight = Color(0xFF052E16); // green-950 bg
  static const Color error        = Color(0xFFF87171); // red-400
  static const Color errorLight   = Color(0xFF450A0A); // red-950 bg
  static const Color warning      = Color(0xFFFBBF24); // amber-400
  static const Color warningLight = Color(0xFF451A03); // amber-950 bg
  static const Color info         = Color(0xFF60A5FA); // blue-400
  static const Color infoLight    = Color(0xFF172554); // blue-950 bg
  static const Color secondary    = Color(0xFFA78BFA); // violet-400

  // POS-specific
  static const Color cartBackground = Color(0xFF18181B);
  static const Color productCard    = Color(0xFF18181B);
  static const Color cashColor      = Color(0xFF4ADE80);
  static const Color cardColor      = Color(0xFF60A5FA);
  static const Color mobilePayColor = Color(0xFFA78BFA);

  // Alias kept for backward compat
  static const Color primaryLight  = Color(0xFF92400E); // amber-800 tint
}
