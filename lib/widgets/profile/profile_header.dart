import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class ProfileHeader extends StatelessWidget {
  final Future<void> Function() onEditTap;

  const ProfileHeader({super.key, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    final email = user?.email ?? '';
    final displayName =
        (name != null && name.isNotEmpty) ? name : (email.isNotEmpty ? email : 'Guest');

    final initials = (name != null && name.isNotEmpty
            ? name[0]
            : (email.isNotEmpty ? email[0] : '?'))
        .toUpperCase();

    // Replicating: bg-primary/10 pt-10 pb-8 flex flex-col items-center rounded-b-[2rem]
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, val, child) {
          return Opacity(
            opacity: val,
            child: Transform.translate(
              offset: Offset(0, 15 * (1 - val)),
              child: child,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 40, bottom: 32),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25), // ~10% opacity roughly
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 96,
                height: 96, // w-24 h-24
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Avatar Ring
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withAlpha(51), // bg-primary/20
                        border: Border.all(
                          color: AppColors.primary.withAlpha(76), // ring-4 ring-primary/30
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 24, // text-2xl
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    // Floating Edit Pencil
                    Positioned(
                      bottom: -4, // -bottom-1
                      right: -4,  // -right-1
                      child: GestureDetector(
                        onTap: onEditTap,
                        child: Container(
                          width: 32, // w-8
                          height: 32, // h-8
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(51),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ), // shadow-lg
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded, // Pencil
                            color: Colors.white, // text-primary-foreground
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: AppText.heading2.copyWith(
                  color: AppColors.foreground,
                ),
              ),
              if (email.isNotEmpty && name != null && name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppText.caption.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
  }
}
