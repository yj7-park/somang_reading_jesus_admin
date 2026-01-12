import 'package:flutter/material.dart';
import '../services/stats_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StatsService _service = StatsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('대시보드')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _service.getStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("오류가 발생했습니다: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final totalUsers = data['totalUsers'] as int;
          final todayReaders = data['todayReaders'] as int;
          final avgProgressPercent = data['avgProgressPercent'] as double;
          final ageStats = data['ageStats'] as Map<String, Map<String, int>>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "현황 요약",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Summary Cards Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildStatCard(
                          title: "총 등록 사용자",
                          value: "$totalUsers명",
                          icon: Icons.group,
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          title: "오늘 통독자",
                          value: "$todayReaders명",
                          subtitle: totalUsers > 0
                              ? "${((todayReaders / totalUsers) * 100).toStringAsFixed(1)}%"
                              : "0%",
                          icon: Icons.menu_book,
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          title: "평균 진행률",
                          value: "${avgProgressPercent.toStringAsFixed(1)}%",
                          subtitle: "오늘 진도 대비 평균",
                          icon: Icons.trending_up,
                          color: Colors.orange,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),
                const Text(
                  "사용자 현황 및 진행률",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "연령대별 통독 현황",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(height: 200, child: _buildAgeChart(ageStats)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgeChart(Map<String, Map<String, int>> ageStats) {
    if (ageStats.isEmpty) return const Center(child: Text("기초 데이터가 없습니다."));

    int maxVal = 0;
    ageStats.forEach((k, v) {
      if ((v['total'] ?? 0) > maxVal) maxVal = v['total']!;
    });
    if (maxVal == 0) maxVal = 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ageStats.entries.map((e) {
        final group = e.key;
        final total = e.value['total'] ?? 0;
        final completed = e.value['completed'] ?? 0;

        final totalHeightPct = total / maxVal;
        final completedHeightPct = completed / maxVal;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  "$completed",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                    fontSize: 10,
                  ),
                ),
                const Text(
                  "/",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  "$total",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Total (Gray)
                Container(
                  width: 30,
                  height: 140 * totalHeightPct + 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                // Completed today (Blue)
                Container(
                  width: 30,
                  height: 140 * completedHeightPct + 4,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(group, style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
