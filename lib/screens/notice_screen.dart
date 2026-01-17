import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notice.dart';
import '../services/notice_service.dart';
import '../widgets/one_ui_app_bar.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final NoticeService _service = NoticeService();
  late final Stream<List<Notice>> _listStream;

  @override
  void initState() {
    super.initState();
    _listStream = _service.getNoticeStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Notice>>(
        stream: _listStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;
          if (list.isEmpty) {
            return CustomScrollView(
              slivers: [
                const SliverOneUIAppBar(title: '공지사항 관리'),
                const SliverFillRemaining(
                  child: Center(child: Text("등록된 공지사항이 없습니다.")),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              const SliverOneUIAppBar(title: '공지사항 관리'),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = list[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '작성일: ${DateFormat('yyyy-MM-dd').format(item.createdAt ?? DateTime.now())}  |  푸시: ${item.sentPush ? "발송됨" : "미발송"}',
                      ),
                      trailing: Switch(
                        value: item.isVisible,
                        onChanged: (val) {
                          _service.updateNotice(
                            Notice(
                              id: item.id,
                              title: item.title,
                              body: item.body,
                              isVisible: val, // toggle
                              sentPush: item.sentPush,
                              createdAt: item.createdAt,
                            ),
                          );
                        },
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(item.body),
                          ),
                        ),
                        OverflowBar(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text("수정"),
                              onPressed: () =>
                                  _showDialog(context, notice: item),
                            ),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.grey,
                              ),
                              label: const Text(
                                "삭제",
                                style: TextStyle(color: Colors.grey),
                              ),
                              onPressed: () => _service.deleteNotice(item.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }, childCount: list.length),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_notice',
        child: const Icon(Icons.add),
        onPressed: () => _showDialog(context),
      ),
    );
  }

  void _showDialog(BuildContext context, {Notice? notice}) {
    final titleCtrl = TextEditingController(text: notice?.title);
    final bodyCtrl = TextEditingController(text: notice?.body);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(notice == null ? "새 공지사항 작성" : "공지사항 수정"),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "제목"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: "본문 내용",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;

                final newNotice = Notice(
                  id: notice?.id ?? '',
                  title: titleCtrl.text,
                  body: bodyCtrl.text,
                  isVisible: notice?.isVisible ?? true,
                  sentPush: notice?.sentPush ?? false,
                  createdAt: notice?.createdAt,
                );

                if (notice == null) {
                  await _service.addNotice(newNotice);
                } else {
                  await _service.updateNotice(newNotice);
                }
                Navigator.pop(context);
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }
}
