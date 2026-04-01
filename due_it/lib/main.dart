import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'screens/auth/lets_start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Disable App Check for development: do not call FirebaseAppCheck.activate().
  // If you add firebase_app_check, use a debug provider in dev or leave it off.
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const DueItRoot(),
    ),
  );
}

class DueItRoot extends StatelessWidget {
  const DueItRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Due It',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const LetsStartScreen(),
    );
  }
}
