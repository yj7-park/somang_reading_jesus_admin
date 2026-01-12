import 'package:flutter/material.dart';
import '../models/content.dart';
import '../services/content_service.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  final ContentService _service = ContentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('컨텐츠 관리')),
      body: StreamBuilder<List<Content>>(
        stream: _service.getContentStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contents = snapshot.data!;
          if (contents.isEmpty) {
            return const Center(child: Text("등록된 컨텐츠가 없습니다."));
          }

          return ReorderableListView.builder(
            itemCount: contents.length,
            onReorder: (oldIndex, newIndex) {
              // Optional: Implement reorder logic updating 'order' field in batch
            },
            itemBuilder: (context, index) {
              final content = contents[index];
              return Card(
                key: ValueKey(content.id),
                child: ListTile(
                  leading: Icon(
                    content.type == ContentType.youtube
                        ? Icons.play_circle_fill
                        : Icons.image,
                    color: content.type == ContentType.youtube
                        ? Colors.red
                        : Colors.green,
                    size: 40,
                  ),
                  title: Text(content.title),
                  subtitle: Text(
                    content.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: content.isVisible,
                        onChanged: (val) {
                          _service.updateContent(
                            Content(
                              id: content.id,
                              type: content.type,
                              title: content.title,
                              url: content.url,
                              isVisible: val, // Update visibility
                              order: content.order,
                              createdAt: content.createdAt,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showDialog(context, content: content),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () => _confirmDelete(content.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_content',
        child: const Icon(Icons.add),
        onPressed: () => _showDialog(context),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("컨텐츠를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              _service.deleteContent(id);
              Navigator.pop(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, {Content? content}) {
    final titleCtrl = TextEditingController(text: content?.title);
    final urlCtrl = TextEditingController(text: content?.url);
    final orderCtrl = TextEditingController(
      text: content?.order.toString() ?? '0',
    );
    ContentType type = content?.type ?? ContentType.image;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(content == null ? "새 컨텐츠 추가" : "컨텐츠 수정"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<ContentType>(
                    value: type,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: ContentType.image,
                        child: Text("이미지 URL"),
                      ),
                      DropdownMenuItem(
                        value: ContentType.youtube,
                        child: Text("YouTube 링크"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => type = val);
                    },
                  ),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: "제목"),
                  ),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: "URL"),
                  ),
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(labelText: "정렬 순서 (숫자)"),
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
                    if (titleCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;

                    final newContent = Content(
                      id: content?.id ?? '', // Service handles new ID
                      type: type,
                      title: titleCtrl.text,
                      url: urlCtrl.text,
                      isVisible: content?.isVisible ?? true,
                      order: int.tryParse(orderCtrl.text) ?? 0,
                      createdAt: content?.createdAt,
                    );

                    if (content == null) {
                      await _service.addContent(newContent);
                    } else {
                      await _service.updateContent(newContent);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text("저장"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
