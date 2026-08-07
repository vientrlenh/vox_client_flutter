import 'package:flutter/material.dart';

import '../core/network/graphql_client.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/personalize/presentation/practice_tab.dart';
import '../features/profile/data/profile_api.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/teacher_exam/presentation/teacher_exam_list_screen.dart';
import '../l10n/app_localizations.dart';

/// Root scaffold that holds the three tabs and the bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _loading = true;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final profile = await ProfileApi(GraphQLClient()).getProfile();
      if (!mounted) return;
      setState(() {
        _isTeacher = profile.roleCode == 'TEACHER';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context)!;

    // Personalized practice is a student feature — teachers keep three tabs.
    final screens = [
      if (_isTeacher) const TeacherExamListScreen() else const HomeScreen(),
      if (!_isTeacher) const PracticeTab(),
      const ScheduleScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // IndexedStack keeps each tab's scroll position alive when switching.
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          if (!_isTeacher)
            NavigationDestination(
              icon: const Icon(Icons.mic_none),
              selectedIcon: const Icon(Icons.mic),
              label: l10n.navPractice,
            ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l10n.navSchedule,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
