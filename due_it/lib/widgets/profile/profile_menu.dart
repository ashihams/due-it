import 'package:flutter/material.dart';


class ProfileMenu extends StatelessWidget {
  final VoidCallback onEditTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;
  final VoidCallback onNotionTap;
  final VoidCallback onSignOutTap;

  const ProfileMenu({
    super.key,
    required this.onEditTap,
    required this.onSettingsTap,
    required this.onSupportTap,
    required this.onNotionTap,
    required this.onSignOutTap,
  });

  @override
  Widget build(BuildContext context) {
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
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white, // bg-card
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          border: Border.all(color: Colors.black.withAlpha(15)), // border border-border
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _MenuItem(
              icon: Icons.person_outline_rounded,
              label: "Edit Profile",
              onTap: onEditTap,
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: "Settings",
              onTap: onSettingsTap,
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.help_outline_rounded,
              label: "Support",
              onTap: onSupportTap,
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.link_rounded,
              label: "Connect to Notion",
              onTap: onNotionTap,
            ),
            const _MenuDivider(),
            _MenuItem(
              icon: Icons.logout_rounded,
              label: "Sign Out",
              onTap: onSignOutTap,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: Colors.black.withAlpha(15), // border-b border-border
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isDestructive ? const Color(0xFFEF4444) : Colors.black87; // text-destructive / text-foreground
    final iconBgColor = isDestructive 
        ? const Color(0xFFEF4444).withAlpha(25) // bg-destructive/10
        : const Color(0xFFF1EEF5).withAlpha(153); // bg-muted/60

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: isDestructive ? const Color(0xFFEF4444).withAlpha(15) : Colors.black.withAlpha(10), // hover:bg-destructive/5 / hover:bg-muted/50
        highlightColor: isDestructive ? const Color(0xFFEF4444).withAlpha(15) : Colors.black.withAlpha(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36, // w-9
                height: 36, // h-9
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: fgColor,
                  ),
                ),
              ),
              const SizedBox(width: 16), // gap-4
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w500,
                    color: fgColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.black38, // text-muted-foreground/40
              ),
            ],
          ),
        ),
      ),
    );
  }
}
