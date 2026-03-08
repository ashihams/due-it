import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppText {
  static const TextStyle heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w500, // Medium weight instead of w600
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500, // Medium weight
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500, // Medium instead of bold
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );
  
  static const TextStyle greeting = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400, // Light weight for calm feel
    color: AppColors.textPrimary,
  );
}

