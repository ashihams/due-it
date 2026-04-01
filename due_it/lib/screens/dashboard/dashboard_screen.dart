import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 112), // matching px-5 pt-8 pb-28 minus horizontal as children handle it
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                DashboardHeader(),
                StreakCard(),
                DashboardGaugeCards(),
                WorkRhythm(),
                HeatmapGridWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
