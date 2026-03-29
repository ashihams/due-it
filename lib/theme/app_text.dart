import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppText {
  static const TextStyle heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.6,
    height: 1.3,
  );

  static const TextStyle greeting = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.2,
  );
}

