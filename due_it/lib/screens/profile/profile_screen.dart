import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../screens/auth/lets_start_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile/profile_widgets.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _refreshUser() async {
    final user = _user;
    if (user != null) {
      await user.reload();
      setState(() {});
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );
    if (updated == true) {
      await _refreshUser();
    }
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'ashihamaheshkumar@gmail.com',
      queryParameters: {
        'subject': 'App Support',
        'body': 'Hi, I need help with...',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email client'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LetsStartScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // We don't use a parent SafeArea so the Header's purple bg can bleed slightly to the top edges
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 112),
        child: Column(
          children: [
            ProfileHeader(
              onEditTap: _openEditProfile,
            ),
            const ProfileStatsRow(),
            ProfileMenu(
              onEditTap: _openEditProfile,
              onSettingsTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              onSupportTap: _openSupportEmail,
              onNotionTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              onSignOutTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}
