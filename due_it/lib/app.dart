import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/add_due/add_due_screen.dart';

class DueItApp extends StatefulWidget {
  const DueItApp({super.key});

  @override
  State<DueItApp> createState() => _DueItAppState();
}

class _DueItAppState extends State<DueItApp> {
  int index = 0;

  final pages = [
    const HomeScreen(),
    const CalendarScreen(),
    const AddDueScreen(),
    const DashboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => setState(() => index = 0),
                icon: Icon(
                  Icons.home,
                  color: index == 0 ? const Color(0xFFA5B4FC) : const Color(0xFF9CA3AF),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => index = 1),
                icon: Icon(
                  Icons.calendar_month,
                  color: index == 1 ? const Color(0xFFA5B4FC) : const Color(0xFF9CA3AF),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => index = 3),
                icon: Icon(
                  Icons.pie_chart,
                  color: index == 3 ? const Color(0xFFA5B4FC) : const Color(0xFF9CA3AF),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => index = 4),
                icon: Icon(
                  Icons.person,
                  color: index == 4 ? const Color(0xFFA5B4FC) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

