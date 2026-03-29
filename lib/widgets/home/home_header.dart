import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../screens/add_due/add_due_screen.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Home",
          style: AppText.heading2.copyWith(
            color: AppColors.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 24, 
          ),
        ),
        _AddButton(),
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddDuePage(),
            ),
          );
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Container(
            width: 48, 
            height: 48, 
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16), 
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                color: AppColors.primaryForeground,
                size: 24, 
              ),
            ),
          ),
        ),
      ),
    );
  }
}
