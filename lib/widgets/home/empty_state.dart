import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FloatingGlassIcon(),
            const SizedBox(height: 16),
            Text(
              "No dues yet",
              style: AppText.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Tap + to add your first task",
              style: AppText.caption.copyWith(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingGlassIcon extends StatefulWidget {
  @override
  State<_FloatingGlassIcon> createState() => _FloatingGlassIconState();
}

class _FloatingGlassIconState extends State<_FloatingGlassIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(seconds: 3),
       vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.6), 
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const Center(
              child: Icon(
                Icons.assignment_outlined, 
                size: 36,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
