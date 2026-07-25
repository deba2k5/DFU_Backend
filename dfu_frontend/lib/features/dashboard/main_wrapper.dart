import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'dashboard_screen.dart';
import '../predict/scan_screen.dart';
import '../profile/profile_screen.dart';
import '../records/records_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const ScanScreen(),
    const RecordsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: AppTheme.primaryCyan,
          unselectedItemColor: AppTheme.textMuted.withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: 'Scan'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_shared_outlined), label: 'Records'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
