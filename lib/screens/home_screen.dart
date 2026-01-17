import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'user_list_screen.dart';
import 'schedule_screen.dart';
import 'content_screen.dart';
import 'notice_screen.dart';
import '../services/auth_service.dart';
import '../providers/navigation_provider.dart';

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
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('대시보드'),
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
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: '대시보드',
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
      appBar: isMobile
          ? AppBar(
              title: const Text('리딩지저스 관리자', style: TextStyle(fontSize: 18)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => AuthService().signOut(),
                  tooltip: '로그아웃',
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) ...[
            NavigationRail(
              selectedIndex: navProvider.selectedIndex,
              onDestinationSelected: (int index) {
                navProvider.setIndex(index);
              },
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Icon(Icons.menu_book, size: 32),
              ),
              destinations: destinations,
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => AuthService().signOut(),
                      tooltip: '로그아웃',
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child: IndexedStack(
              index: navProvider.selectedIndex,
              children: _screens,
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
