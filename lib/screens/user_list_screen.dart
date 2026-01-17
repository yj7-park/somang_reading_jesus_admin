import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/church_roster.dart';
import '../services/user_roster_service.dart';
import '../utils/format_helper.dart';
import '../widgets/one_ui_app_bar.dart';
import '../providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'user_detail_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserAndRosterService _service = UserAndRosterService();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();
  String _filterStatus = 'All'; // All, Registered, Unregistered
  late final Stream<Map<String, dynamic>> _dataStream;

  @override
  void initState() {
    super.initState();
    _dataStream = _service.getCombinedUserRosterStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(snapshot.error.toString());
          return Scaffold(
            appBar: AppBar(title: const Text('사용자 관리')),
            body: Center(child: Text("오류가 발생했습니다")),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('사용자 관리')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final List<UserProfile> users = data['users'];
        final List<ChurchRoster> roster = data['roster'];
        final Map<String, Map<String, dynamic>> userStats = data['stats'];
        final Set<String> todayCompletedUids = data['todayCompletedUids'] ?? {};
        final int targetIndex = data['targetIndex'] ?? 270;

        // Merge Logic:
        final Set<String> registeredPhones = users
            .map((u) => u.phoneNumber)
            .toSet();
        final List<dynamic> mergedList = [...users];

        for (var r in roster) {
          if (!registeredPhones.contains(r.phoneNumber)) {
            mergedList.add(r);
          }
        }

        // Filter
        List<dynamic> filteredList = mergedList.where((item) {
          bool isRegistered = item is UserProfile;

          // Status Filter (Registered/Unregistered)
          if (_filterStatus == 'Registered' && !isRegistered) return false;
          if (_filterStatus == 'Unregistered' && isRegistered) return false;

          // Today's Reader Filter (Task-specific)
          if (navProvider.showOnlyTodayReaders) {
            if (!isRegistered) return false;
            if (!todayCompletedUids.contains(item.uid)) {
              return false;
            }
          }

          return true;
        }).toList();

        // Search
        if (_searchController.text.isNotEmpty) {
          final term = _searchController.text;
          final cleanTerm = term.replaceAll(RegExp(r'[^0-9]'), '');

          filteredList = filteredList.where((item) {
            final name = item is UserProfile
                ? item.name
                : (item as ChurchRoster).name;
            final rawPhone = item is UserProfile
                ? item.phoneNumber
                : (item as ChurchRoster).phoneNumber;

            final formattedPhone = FormatHelper.formatPhone(rawPhone);
            final cleanPhone = formattedPhone.replaceAll(RegExp(r'[^0-9]'), '');

            bool nameMatch = name.contains(term);
            bool phoneMatch =
                formattedPhone.contains(term) ||
                (cleanTerm.isNotEmpty && cleanPhone.contains(cleanTerm));

            return nameMatch || phoneMatch;
          }).toList();
        }

        filteredList.sort((a, b) {
          final nameA = a is UserProfile ? a.name : (a as ChurchRoster).name;
          final nameB = b is UserProfile ? b.name : (b as ChurchRoster).name;
          return nameA.compareTo(nameB);
        });

        int registeredCount = users.length;
        int unregisteredCount = mergedList.length - registeredCount;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverOneUIAppBar(title: '사용자 관리'),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Animated Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: _isSearchExpanded
                                ? (MediaQuery.of(context).size.width > 600
                                      ? 400
                                      : MediaQuery.of(context).size.width - 32)
                                : 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _isSearchExpanded
                                    ? Colors.blue.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                              boxShadow: [
                                if (_isSearchExpanded)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                if (_isSearchExpanded)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16.0,
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        decoration: const InputDecoration(
                                          hintText: '이름 / 전화번호 검색',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onChanged: (v) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _isSearchExpanded
                                        ? Icons.close
                                        : Icons.search,
                                    color: Colors.black87,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchExpanded = !_isSearchExpanded;
                                      if (_isSearchExpanded) {
                                        _searchFocusNode.requestFocus();
                                      } else {
                                        _searchController.clear();
                                        _searchFocusNode.unfocus();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Summary stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isNarrow = constraints.maxWidth < 400;
                          final filters = [
                            _buildFilterChip(
                              label: "전체: ${mergedList.length}",
                              value: 'All',
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: "가입: $registeredCount",
                              value: 'Registered',
                              activeColor: Colors.blue.withOpacity(0.1),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: "미가입: $unregisteredCount",
                              value: 'Unregistered',
                              activeColor: Colors.orange.withOpacity(0.1),
                            ),
                          ];

                          final todayFilter = _buildTodayFilterChip(
                            navProvider,
                          );

                          if (isNarrow) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.start,
                              children: [
                                ...filters.where((w) => w is! SizedBox),
                                todayFilter,
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                ...filters,
                                const Spacer(),
                                todayFilter,
                              ],
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = filteredList[index];
                  final isRegistered = item is UserProfile;

                  final stats = isRegistered ? userStats[item.uid] : null;
                  final completed = stats?['total_days_completed'] as num? ?? 0;
                  final totalDays = targetIndex > 0 ? targetIndex : 1;
                  final progress = (completed / totalDays * 100)
                      .toStringAsFixed(1);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: InkWell(
                      onTap: isRegistered
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailScreen(user: item),
                                ),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isRegistered
                                  ? Colors.blue
                                  : Colors.grey,
                              child: Icon(
                                isRegistered
                                    ? Icons.check
                                    : Icons.person_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Left Area: User Info (flex 1)
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isRegistered
                                        ? item.name
                                        : (item as ChurchRoster).name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        FormatHelper.formatPhone(
                                          isRegistered
                                              ? item.phoneNumber
                                              : (item as ChurchRoster)
                                                    .phoneNumber,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        isRegistered
                                            ? (item.birthDate ?? "")
                                            : (item as ChurchRoster).birthDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Right Area: Progress Info (flex 1)
                            Expanded(
                              flex: 1,
                              child: isRegistered
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "$completed/$totalDays ($progress%)",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 100,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: completed / totalDays,
                                              backgroundColor: Colors.grey[200],
                                              color: Colors.green,
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        "미등록",
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: filteredList.length),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_user_list',
            icon: const Icon(Icons.person_add),
            label: const Text("멤버 추가"),
            onPressed: () => _showAddMemberDialog(context),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    Color? activeColor,
  }) {
    final bool isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = value);
        }
      },
      selectedColor:
          activeColor ?? Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? (activeColor?.withOpacity(0.5) ??
                    Theme.of(context).primaryColor)
              : Colors.grey.shade300,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildTodayFilterChip(NavigationProvider navProvider) {
    final bool isSelected = navProvider.showOnlyTodayReaders;
    return FilterChip(
      label: const Text("오늘의 통독자", style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        navProvider.setShowOnlyTodayReaders(selected);
      },
      selectedColor: Colors.green.withOpacity(0.2),
      checkmarkColor: Colors.green,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.green : Colors.grey.shade300,
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dobCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새 멤버 추가"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "이름"),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: "전화번호",
                hintText: "010-1234-5678",
              ),
            ),
            TextField(
              controller: dobCtrl,
              decoration: const InputDecoration(
                labelText: "생년월일 (YYYY-MM-DD)",
                hintText: "1990-01-01",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              await _service.addToRoster(
                ChurchRoster(
                  name: nameCtrl.text,
                  phoneNumber: phoneCtrl.text,
                  birthDate: dobCtrl.text,
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("추가"),
          ),
        ],
      ),
    );
  }
}
