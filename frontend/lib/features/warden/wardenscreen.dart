import 'package:flutter/material.dart';
import '../../../core/navigation/logout_button.dart';
import '../../../features/warden/reports_screen.dart';
import 'search_student_screen.dart';
import '../../../features/warden/requests_screen.dart';
import '../../services/notification_service.dart';

class WardenScreen extends StatefulWidget {
  const WardenScreen({super.key});

  @override
  State<WardenScreen> createState() => _WardenScreenState();
}

class _WardenScreenState extends State<WardenScreen> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.init(context);
  }

  @override
  void dispose() {
    NotificationService.dispose();
    super.dispose();
  }

  final screens = [
    const RequestsScreen(),
    const SearchStudentScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: screens[index],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => index = i);
        },
        height: 70,
        elevation: 10,
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pending_actions_rounded),
            selectedIcon: Icon(Icons.pending_actions_rounded, color: Color(0xFF2D5AF0)),
            label: "Requests",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_search_rounded),
            selectedIcon: Icon(Icons.person_search_rounded, color: Color(0xFF2D5AF0)),
            label: "Directory",
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF2D5AF0)),
            label: "Reports",
          ),
        ],
      ),
    );
  }
}