import 'package:flutter/material.dart';
import '../../auth/auth_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class LetsStartScreen extends StatelessWidget {
  const LetsStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
        child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  const SizedBox(height: 20),

              // Title
                  Text(
                "Due It",
                    style: AppText.heading1.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                ),
              ),

                  const SizedBox(height: 40),

                  // Orb placeholder with pastel gradient
              Container(
                    height: 200,
                    width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                          AppColors.primary,
                          AppColors.accent,
                          AppColors.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                          color: AppColors.primary.withOpacity(0.25),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                        height: 140,
                        width: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.4),
                        ),
                        child: Icon(
                          Icons.task_alt_rounded,
                          size: 70,
                          color: AppColors.primary,
                    ),
                  ),
                ),
              ),

                  const SizedBox(height: 40),

              // Text
                  Text(
                "Easy organize your\ndues & enjoy\nyour day",
                textAlign: TextAlign.center,
                    style: AppText.heading1.copyWith(
                      fontSize: 28,
                      height: 1.3,
                      color: AppColors.textPrimary,
                ),
              ),

                  const SizedBox(height: 60),

              // Sign In Button
                  Container(
                width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.primary,
                          AppColors.accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuthPage(initialIsLogin: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                      child: Text(
                        "Sign In",
                        style: AppText.bodyBold.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                    ),
                  ),
                ),
              ),

                  const SizedBox(height: 16),

              // Sign Up Button
                  Container(
                width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuthPage(initialIsLogin: false),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                      ),
                  ),
                      child: Text(
                    "Sign Up",
                        style: AppText.bodyBold.copyWith(
                          fontSize: 16,
                          color: AppColors.primary,
                    ),
                  ),
                ),
              ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
