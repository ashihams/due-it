import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/notion_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notionService = NotionService();
  bool _connectingNotion = false;
  bool _disconnectingNotion = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _connectNotion() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _connectingNotion = true);
    try {
      final authUrl = await _notionService.getNotionAuthUrl(uid);
      if (!mounted) return;

      if (authUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get Notion auth URL. Try again.')),
        );
        return;
      }

      final uri = Uri.parse(authUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingNotion = false);
    }
  }

  Future<void> _disconnectNotion() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _disconnectingNotion = true);
    try {
      final success = await _notionService.disconnectNotion(uid);
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disconnect. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _disconnectingNotion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Settings',
                    style: AppText.heading2.copyWith(color: AppColors.foreground),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 32),

              // ── Section label ────────────────────────────────────────
              Text(
                'INTEGRATIONS',
                style: AppText.label.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),

              // ── Notion card ──────────────────────────────────────────
              if (uid == null)
                const SizedBox.shrink()
              else
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _notionService.notionStatusStream(uid),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final connected = (data?['notionConnected'] as bool?) ?? false;
                    final workspace = data?['notionWorkspace'] as String?;

                    return _NotionCard(
                      connected: connected,
                      workspaceName: workspace,
                      connecting: _connectingNotion,
                      disconnecting: _disconnectingNotion,
                      onConnect: _connectNotion,
                      onDisconnect: _disconnectNotion,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notion card ────────────────────────────────────────────────────────────────

class _NotionCard extends StatelessWidget {
  final bool connected;
  final String? workspaceName;
  final bool connecting;
  final bool disconnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _NotionCard({
    required this.connected,
    required this.workspaceName,
    required this.connecting,
    required this.disconnecting,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Notion logo — black rounded square with "N"
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notion',
                  style: AppText.bodyBold.copyWith(color: AppColors.foreground),
                ),
                const SizedBox(height: 3),
                if (connected)
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          workspaceName != null
                              ? 'Connected to $workspaceName'
                              : 'Connected',
                          style: AppText.caption.copyWith(color: AppColors.success),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Not connected',
                    style: AppText.caption.copyWith(color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action button
          if (connected)
            _ActionButton(
              label: 'Disconnect',
              loading: disconnecting,
              onTap: onDisconnect,
              isDestructive: true,
            )
          else
            _ActionButton(
              label: 'Connect Notion',
              loading: connecting,
              onTap: onConnect,
              isDestructive: false,
            ),
        ],
      ),
    );
  }
}

// ── Small pill action button ───────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? const Color(0xFFEF4444).withAlpha(20)
        : AppColors.primary.withAlpha(20);
    final fgColor =
        isDestructive ? const Color(0xFFEF4444) : AppColors.primary;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
      ),
    );
  }
}
