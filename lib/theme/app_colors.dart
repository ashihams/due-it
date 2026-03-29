import 'package:flutter/material.dart';

class AppColors {
  // Global React colors converted using HSLColor for exact precision:
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF212131);
  
  static const Color primary = Color(0xFF866CEF);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  
  static const Color muted = Color(0xFFEAE9F2);
  static const Color mutedForeground = Color(0xFF818198);
  
  static const Color border = Color(0xFFE2E0EB);
  static const Color success = Color(0xFF31C47F);
  
  // Kept from original to avoid breaking unmigrated screens
  static const Color secondary = Color(0xFFFBCFE8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF3A3A5A);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color accent = Color(0xFFC7D2FE);
  
  static const Color lavender = Color(0xFFA5B4FC);
  static const Color lilac = Color(0xFFC7D2FE);
  static const Color softBlue = Color(0xFFB8D4F0);
  static const Color lightPink = Color(0xFFFBCFE8);
  
  static const Color completedBackground = Color(0xFFF0F4FF);
  static const Color completedText = Color(0xFF9CA3AF);
  static const Color completedCheck = Color(0xFFA5B4FC);
}

class GroupColors {
  final Color bgCard;
  final Color iconBg;
  final Color progress;
  final Color border;

  const GroupColors({
    required this.bgCard,
    required this.iconBg,
    required this.progress,
    required this.border,
  });
}

const Map<String, GroupColors> groupThemeColors = {
  "Work": GroupColors(
    bgCard: Color(0xFFF5EFFB),
    iconBg: Color(0xFFEBDEF7),
    border: Color(0xFFA679D2),
    progress: Color(0xFFA679D2),
  ),
  "Study": GroupColors(
    bgCard: Color(0xFFE9F5FB),
    iconBg: Color(0xFFD4EBF7),
    border: Color(0xFF2D9BD2),
    progress: Color(0xFF2D9BD2),
  ),
  "Personal": GroupColors(
    bgCard: Color(0xFFE8F7F0),
    iconBg: Color(0xFFD9F2E6),
    border: Color(0xFF39AC73),
    progress: Color(0xFF39AC73),
  ),
};
