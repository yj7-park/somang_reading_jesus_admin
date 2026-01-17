import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'user_list_screen.dart';
import 'schedule_screen.dart';
import 'content_screen.dart';
import 'notice_screen.dart';
import '../providers/navigation_provider.dart';
import '../widgets/admin_profile_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = [
    const DashboardScreen(),
    const UserListScreen(),
    const ScheduleScreen(),
    const ContentScreen(), // Helper: ensure import
    const NoticeScreen(), // Helper: ensure import
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    final destinations = const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('홈'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: Text('사용자 관리'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: Text('통독 일정'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: Text('컨텐츠 관리'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.notifications_outlined),
        selectedIcon: Icon(Icons.notifications),
        label: Text('공지사항'),
      ),
    ];

    final bottomDestinations = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: '홈',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.people_outlined),
        activeIcon: Icon(Icons.people),
        label: '사용자',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        activeIcon: Icon(Icons.calendar_month),
        label: '일정',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.video_library_outlined),
        activeIcon: Icon(Icons.video_library),
        label: '컨텐츠',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        activeIcon: Icon(Icons.notifications),
        label: '공지',
      ),
    ];

    return Scaffold(
      appBar: null,
      body: Row(
        children: [
          if (!isMobile) ...[
            NavigationRail(
              selectedIndex: navProvider.selectedIndex,
              onDestinationSelected: (int index) {
                navProvider.setIndex(index);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Image.asset(
                  'assets/icon/official_icon_transparent.png',
                  width: 80,
                  height: 80,
                ),
              ),
              destinations: destinations,
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: const AdminProfileButton(showLabel: true),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: IndexedStack(
                  index: navProvider.selectedIndex,
                  children: _screens,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: navProvider.selectedIndex,
              onTap: (index) => navProvider.setIndex(index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              items: bottomDestinations,
            )
          : null,
    );
  }
}
