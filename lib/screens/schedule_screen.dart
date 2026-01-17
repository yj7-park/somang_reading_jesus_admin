import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/reading_schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/one_ui_app_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _service = ScheduleService();
  String _selectedYear = DateTime.now().year.toString();
  List<String> _availableYears = [];
  late Stream<ReadingSchedule?> _scheduleStream;
  bool _isYearSelectorExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  void _loadYears() async {
    final yearsFromDb = await _service.getAvailableYears();
    final currentYear = DateTime.now().year;
    final nextYear = currentYear + 1;

    final Set<String> yearSet = Set.from(yearsFromDb);
    yearSet.add(currentYear.toString());
    yearSet.add(nextYear.toString());

    final sortedYears = yearSet.toList()..sort();

    if (mounted) {
      setState(() {
        _availableYears = sortedYears;
        if (!_availableYears.contains(_selectedYear)) {
          _selectedYear = currentYear.toString();
        }
        _scheduleStream = _service.getScheduleStream(_selectedYear);
      });
    }
  }

  void _onYearSelected(String year) async {
    final schedule = await _service.getScheduleStream(year).first;

    if (schedule == null) {
      // Create default schedule without startDate
      await _service.saveSchedule(ReadingSchedule(year: year, holidays: []));
    }

    if (mounted) {
      setState(() {
        _selectedYear = year;
        _scheduleStream = _service.getScheduleStream(year);
        _isYearSelectorExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverOneUIAppBar(title: '통독 일정 관리'),
          StreamBuilder<ReadingSchedule?>(
            stream: _scheduleStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final schedule = snapshot.data;
              if (schedule == null) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No Data')),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // Animated Year Selector (Right Aligned)
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
                          width: _isYearSelectorExpanded
                              ? (MediaQuery.of(context).size.width > 600
                                    ? 400
                                    : MediaQuery.of(context).size.width - 32)
                              : 120,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isYearSelectorExpanded
                                  ? Colors.blue.withOpacity(0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isYearSelectorExpanded)
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Row(
                                      children: _availableYears.map((year) {
                                        final isSelected =
                                            _selectedYear == year;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                          ),
                                          child: ChoiceChip(
                                            label: Text('$year년'),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              if (selected) {
                                                _onYearSelected(year);
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              if (!_isYearSelectorExpanded)
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      setState(() {
                                        _isYearSelectorExpanded = true;
                                      });
                                    },
                                    child: Center(
                                      child: Text(
                                        '$_selectedYear년',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isYearSelectorExpanded)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _isYearSelectorExpanded = false;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detail Content
                  _buildScheduleDetail(schedule),
                ]),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildScheduleDetail(ReadingSchedule schedule) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Start Date Section
          Card(
            child: ListTile(
              title: const Text('통독 시작일'),
              subtitle: schedule.startDate != null
                  ? Text(
                      DateFormat(
                        'yyyy-MM-dd (E)',
                        'ko_KR',
                      ).format(schedule.startDate!),
                    )
                  : const Text(
                      '등록 정보 없음',
                      style: TextStyle(color: Colors.grey),
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _pickDate(
                  context,
                  schedule.startDate ??
                      DateTime(int.parse(schedule.year), 1, 1),
                  (date) async {
                    final newSchedule = ReadingSchedule(
                      year: schedule.year,
                      startDate: date,
                      holidays: schedule.holidays,
                    );
                    await _service.saveSchedule(newSchedule);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Holidays Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '휴식 기간 설정',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              FilledButton.icon(
                onPressed: () => _addHolidayDialog(schedule),
                icon: const Icon(Icons.add),
                label: const Text('휴식 기간 추가'),
              ),
            ],
          ),
          const Divider(),
          if (schedule.holidays.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("설정된 휴식 기간이 없습니다."),
            ),

          ...([]
                ..addAll(schedule.holidays)
                ..sort((a, b) => a.start.compareTo(b.start)))
              .asMap()
              .entries
              .map((entry) {
                final range = entry.value;
                final idx = schedule.holidays.indexOf(
                  range,
                ); // Use real index for deletion
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.beach_access),
                    title: Text(
                      '${DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(range.start)} ~ ${DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(range.end)}',
                    ),
                    subtitle:
                        range.description != null &&
                            range.description!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              range.description!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        // Remove item
                        final newHolidays = List<ScheduleDateRange>.from(
                          schedule.holidays,
                        );
                        newHolidays.removeAt(idx);
                        await _service.saveSchedule(
                          ReadingSchedule(
                            year: schedule.year,
                            startDate: schedule.startDate,
                            holidays: newHolidays,
                          ),
                        );
                      },
                    ),
                  ),
                );
              })
              .toList(),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime initial,
    Function(DateTime) onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) onPicked(picked);
  }

  void _addHolidayDialog(ReadingSchedule schedule) async {
    DateTime focusedDay = DateTime.now();
    DateTime? rangeStart;
    DateTime? rangeEnd;
    RangeSelectionMode rangeSelectionMode = RangeSelectionMode.toggledOn;
    final TextEditingController descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("휴식 기간 추가"),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "기존 휴식 기간은 회색으로 표시됩니다.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TableCalendar(
                        firstDay: DateTime(2000),
                        lastDay: DateTime(2030),
                        focusedDay: focusedDay,
                        locale: 'ko_KR',
                        rangeStartDay: rangeStart,
                        rangeEndDay: rangeEnd,
                        rangeSelectionMode: rangeSelectionMode,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                        ),
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        onRangeSelected: (start, end, focused) {
                          setDialogState(() {
                            rangeStart = start;
                            rangeEnd = end;
                            focusedDay = focused;
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final holiday = schedule.holidays
                                .cast<ScheduleDateRange?>()
                                .firstWhere(
                                  (r) =>
                                      r != null &&
                                      (day.isAfter(r.start) ||
                                          isSameDay(day, r.start)) &&
                                      (day.isBefore(r.end) ||
                                          isSameDay(day, r.end)),
                                  orElse: () => null,
                                );

                            if (holiday != null) {
                              return Tooltip(
                                message: holiday.description ?? "휴식",
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    day.day.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: '휴식 사유',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                ElevatedButton(
                  onPressed: (rangeStart == null || rangeEnd == null)
                      ? null
                      : () async {
                          // Check for overlaps
                          final hasOverlap = schedule.holidays.any((range) {
                            return (rangeStart!.isBefore(range.end) ||
                                    isSameDay(rangeStart, range.end)) &&
                                (rangeEnd!.isAfter(range.start) ||
                                    isSameDay(rangeEnd, range.start));
                          });

                          if (hasOverlap) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("선택한 기간이 기존 휴식 기간과 겹칩니다."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Save
                          final newHolidays = List<ScheduleDateRange>.from(
                            schedule.holidays,
                          );
                          newHolidays.add(
                            ScheduleDateRange(
                              start: rangeStart!,
                              end: rangeEnd!,
                              description: descCtrl.text.trim(),
                            ),
                          );

                          await _service.saveSchedule(
                            ReadingSchedule(
                              year: schedule.year,
                              startDate: schedule.startDate,
                              holidays: newHolidays,
                            ),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text("추가"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
