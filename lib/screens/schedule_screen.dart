import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/reading_schedule.dart';
import '../services/schedule_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _service = ScheduleService();
  String _selectedYear = DateTime.now().year.toString();
  List<String> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  void _loadYears() async {
    final years = await _service.getAvailableYears();
    if (years.isNotEmpty) {
      if (mounted) {
        setState(() {
          _availableYears = years;
          if (!_availableYears.contains(_selectedYear)) {
            _selectedYear = _availableYears.first;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _availableYears = [_selectedYear];
        });
      }
    }
  }

  void _createNewYear() async {
    // Logic to create a new year doc
    // For now just add next year to list locally and let save create it
    final nextYear = (int.parse(_availableYears.last) + 1).toString();
    setState(() {
      _availableYears.add(nextYear);
      _selectedYear = nextYear;
    });
    // Actually save basic structure
    await _service.saveSchedule(
      ReadingSchedule(
        year: nextYear,
        startDate: DateTime(int.parse(nextYear), 1, 1),
        holidays: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통독 일정 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 연도 추가',
            onPressed: _createNewYear,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 600;

          final detailPanel = StreamBuilder<ReadingSchedule?>(
            stream: _service.getScheduleStream(_selectedYear),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final schedule = snapshot.data;
              if (schedule == null) {
                return const Center(child: Text('No Data'));
              }

              return _buildScheduleDetail(schedule);
            },
          );

          if (isNarrow) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: '연도 선택',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text('$year년'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedYear = v);
                    },
                  ),
                ),
                Expanded(child: detailPanel),
              ],
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Year Selector
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: ListView(
                    children: _availableYears
                        .map(
                          (year) => ListTile(
                            title: Text('$year년'),
                            selected: year == _selectedYear,
                            onTap: () => setState(() => _selectedYear = year),
                          ),
                        )
                        .toList(),
                  ),
                ),

                // Right Panel: Details
                Expanded(child: detailPanel),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildScheduleDetail(ReadingSchedule schedule) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Start Date Section
        Card(
          child: ListTile(
            title: const Text('통독 시작일'),
            subtitle: Text(
              DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(schedule.startDate),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  _pickDate(context, schedule.startDate, (date) async {
                    final newSchedule = ReadingSchedule(
                      year: schedule.year,
                      startDate: date,
                      holidays: schedule.holidays,
                    );
                    await _service.saveSchedule(newSchedule);
                  }),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Holidays Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('휴식 기간 설정', style: Theme.of(context).textTheme.headlineSmall),
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
                      range.description != null && range.description!.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            range.description!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
            }),
      ],
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
