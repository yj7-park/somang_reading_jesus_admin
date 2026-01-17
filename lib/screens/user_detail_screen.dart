import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/user_profile.dart';
import '../models/reading_schedule.dart';
import '../services/user_roster_service.dart';
import '../services/user_progress_service.dart';
import '../utils/format_helper.dart';
import '../utils/date_helper.dart';

import '../widgets/one_ui_app_bar.dart';

class UserDetailScreen extends StatefulWidget {
  final UserProfile user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dobCtrl;

  final UserAndRosterService _userService = UserAndRosterService();
  final UserProgressService _progressService = UserProgressService();

  // Calendar State
  late final ValueNotifier<List<DateTime>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<DateTime> _completedDates = [];
  bool _loadingCalendar = true;
  ReadingSchedule? _currentSchedule;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _phoneCtrl = TextEditingController(
      text: FormatHelper.formatPhone(widget.user.phoneNumber),
    );
    _dobCtrl = TextEditingController(text: widget.user.birthDate);
    _selectedEvents = ValueNotifier(_completedDates);
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    final dates = await _progressService.getUserReadings(widget.user.uid);
    final schedule = await _progressService.getSchedule(_focusedDay.year);
    if (mounted) {
      setState(() {
        _completedDates = dates;
        _currentSchedule = schedule;
        _loadingCalendar = false;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    // 1. Block future dates (tomorrow and beyond)
    final now = DateTime.now();
    final bool isFuture =
        selectedDay.year > now.year ||
        (selectedDay.year == now.year && selectedDay.month > now.month) ||
        (selectedDay.year == now.year &&
            selectedDay.month == now.month &&
            selectedDay.day > now.day);

    if (isFuture) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("미래 날짜는 선택할 수 없습니다.")));
      return;
    }

    // 2. Block Sundays
    if (selectedDay.weekday == DateTime.sunday) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("일요일은 통독일이 아닙니다.")));
      return;
    }

    // 3. Prevent selection of holidays
    if (_currentSchedule != null) {
      bool isHoliday = false;
      for (final holiday in _currentSchedule!.holidays) {
        if ((selectedDay.isAfter(holiday.start) ||
                DateHelper.isSameDay(selectedDay, holiday.start)) &&
            (selectedDay.isBefore(holiday.end) ||
                DateHelper.isSameDay(selectedDay, holiday.end))) {
          isHoliday = true;
          break;
        }
      }
      if (isHoliday) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("통독 휴식 기간은 선택할 수 없습니다.")));
        return;
      }
    }

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // Determine if completed
    final isCompleted = _completedDates.any((d) => isSameDay(d, selectedDay));

    // Optimistic update
    List<DateTime> updatedList = List.from(_completedDates);
    if (isCompleted) {
      updatedList.removeWhere((d) => isSameDay(d, selectedDay));
    } else {
      updatedList.add(selectedDay);
    }
    setState(() => _completedDates = updatedList);

    // Server update
    try {
      await _progressService.toggleReading(widget.user.uid, selectedDay);
    } catch (e) {
      debugPrint("Toggle UI Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("기록 업데이트 중 오류가 발생했습니다: $e")));
        // Rollback optimistic update
        _loadReadings();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverOneUIAppBar(title: widget.user.name),
          SliverFillRemaining(
            hasScrollBody: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;

                final profilePanel = Container(
                  width: isNarrow ? double.infinity : 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: isNarrow
                        ? Border(top: BorderSide(color: Colors.grey.shade300))
                        : Border(
                            right: BorderSide(color: Colors.grey.shade300),
                          ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "사용자 프로필",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: "이름"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "전화번호 (수정 불가)",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _dobCtrl,
                        decoration: const InputDecoration(labelText: "생년월일"),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _userService.updateUser(widget.user.uid, {
                            'name': _nameCtrl.text,
                            'birthDate': _dobCtrl.text,
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("프로필이 업데이트되었습니다.")),
                            );
                          }
                        },
                        child: const Text("저장하기"),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          setState(() => _loadingCalendar = true);
                          try {
                            await _progressService.recalculateUserStats(
                              widget.user.uid,
                            );
                            await _loadReadings(); // Refresh UI
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("통계가 동기화되었습니다.")),
                              );
                            }
                          } catch (e) {
                            debugPrint("Sync Error: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("동기화 중 오류가 발생했습니다: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted)
                              setState(() => _loadingCalendar = false);
                          }
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text("통계 동기화"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                );

                final calendarPanel = Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "통독 기록",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: _loadingCalendar
                          ? const SizedBox(
                              height: 400,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : SizedBox(
                              height: isNarrow ? 400 : null,
                              child: TableCalendar(
                                locale: 'ko_KR',
                                sixWeekMonthsEnforced: true,
                                firstDay:
                                    _currentSchedule?.startDate ??
                                    DateTime(2020),
                                lastDay: _currentSchedule != null
                                    ? DateHelper.getEndDate(_currentSchedule!)
                                    : DateTime(2030),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                holidayPredicate: (day) {
                                  if (_currentSchedule == null) return false;
                                  for (final holiday
                                      in _currentSchedule!.holidays) {
                                    if ((day.isAfter(holiday.start) ||
                                            DateHelper.isSameDay(
                                              day,
                                              holiday.start,
                                            )) &&
                                        (day.isBefore(holiday.end) ||
                                            DateHelper.isSameDay(
                                              day,
                                              holiday.end,
                                            ))) {
                                      return true;
                                    }
                                  }
                                  return false;
                                },
                                enabledDayPredicate: (day) {
                                  final now = DateTime.now();
                                  final bool isFuture =
                                      day.year > now.year ||
                                      (day.year == now.year &&
                                          day.month > now.month) ||
                                      (day.year == now.year &&
                                          day.month == now.month &&
                                          day.day > now.day);
                                  if (isFuture) return false;
                                  if (day.weekday == DateTime.sunday)
                                    return false;
                                  if (_currentSchedule == null) return true;
                                  for (final holiday
                                      in _currentSchedule!.holidays) {
                                    if ((day.isAfter(holiday.start) ||
                                            DateHelper.isSameDay(
                                              day,
                                              holiday.start,
                                            )) &&
                                        (day.isBefore(holiday.end) ||
                                            DateHelper.isSameDay(
                                              day,
                                              holiday.end,
                                            ))) {
                                      return false;
                                    }
                                  }
                                  return true;
                                },
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                onDaySelected: _onDaySelected,
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                ),
                                availableCalendarFormats: const {
                                  CalendarFormat.month: 'Month',
                                },
                                onPageChanged: (focusedDay) async {
                                  final oldYear = _focusedDay.year;
                                  _focusedDay = focusedDay;
                                  if (focusedDay.year != oldYear) {
                                    setState(() => _loadingCalendar = true);
                                    final schedule = await _progressService
                                        .getSchedule(focusedDay.year);
                                    if (mounted) {
                                      setState(() {
                                        _currentSchedule = schedule;
                                        _loadingCalendar = false;
                                      });
                                    }
                                  }
                                },
                                calendarBuilders: CalendarBuilders(
                                  selectedBuilder: (context, day, focusedDay) {
                                    final isToday = isSameDay(
                                      day,
                                      DateTime.now(),
                                    );
                                    final isCompleted = _completedDates.any(
                                      (d) => isSameDay(d, day),
                                    );
                                    return Container(
                                      decoration: isToday
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            )
                                          : null,
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? Colors.green
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.purple,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          day.day.toString(),
                                          style: TextStyle(
                                            color: isCompleted
                                                ? Colors.white
                                                : (isToday
                                                      ? Colors.blue.shade900
                                                      : Colors.black),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  todayBuilder: (context, day, focusedDay) {
                                    final isCompleted = _completedDates.any(
                                      (d) => isSameDay(d, day),
                                    );
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: isCompleted
                                          ? Container(
                                              margin: const EdgeInsets.all(4),
                                              alignment: Alignment.center,
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                day.day.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                day.day.toString(),
                                                style: TextStyle(
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    );
                                  },
                                  defaultBuilder: (context, day, focusedDay) {
                                    final isCompleted = _completedDates.any(
                                      (d) => isSameDay(d, day),
                                    );
                                    if (isCompleted) {
                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          day.day.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                  disabledBuilder: (context, day, focusedDay) {
                                    ScheduleDateRange? holiday;
                                    if (_currentSchedule != null) {
                                      for (final h
                                          in _currentSchedule!.holidays) {
                                        if ((day.isAfter(h.start) ||
                                                DateHelper.isSameDay(
                                                  day,
                                                  h.start,
                                                )) &&
                                            (day.isBefore(h.end) ||
                                                DateHelper.isSameDay(
                                                  day,
                                                  h.end,
                                                ))) {
                                          holiday = h;
                                          break;
                                        }
                                      }
                                    }
                                    if (holiday != null) {
                                      return Tooltip(
                                        message: holiday.description ?? "휴식 기간",
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            day.day.toString(),
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                  holidayBuilder: (context, day, focusedDay) {
                                    ScheduleDateRange? holiday;
                                    if (_currentSchedule != null) {
                                      for (final h
                                          in _currentSchedule!.holidays) {
                                        if ((day.isAfter(h.start) ||
                                                DateHelper.isSameDay(
                                                  day,
                                                  h.start,
                                                )) &&
                                            (day.isBefore(h.end) ||
                                                DateHelper.isSameDay(
                                                  day,
                                                  h.end,
                                                ))) {
                                          holiday = h;
                                          break;
                                        }
                                      }
                                    }
                                    return Tooltip(
                                      message: holiday?.description ?? "휴식 기간",
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          day.day.toString(),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ), // end of CalendarBuilders
                              ), // end of TableCalendar
                            ), // end of SizedBox
                    ), // end of Expanded
                  ],
                );

                if (isNarrow) {
                  return SingleChildScrollView(
                    child: Column(children: [calendarPanel, profilePanel]),
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      profilePanel,
                      Expanded(child: calendarPanel),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
