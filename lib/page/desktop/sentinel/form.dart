import 'package:athena/api/sentinel.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SentinelFormPage extends StatefulWidget {
  const SentinelFormPage({super.key});

  @override
  State<SentinelFormPage> createState() => _SentinelFormPageState();
}

class _SentinelFormPageState extends State<SentinelFormPage> {
  final controller = TextEditingController();
  String avatar = '';
  String name = '';
  String description = '';
  List<String> tags = [];

  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadow = colorScheme.shadow;
    final onSurface = colorScheme.onSurface;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          const _Placeholder(),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const _Placeholder(),
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: shadow.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                      color: colorScheme.surface,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          avatar.isEmpty ? '🤖' : avatar,
                          style: const TextStyle(fontSize: 64),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: onSurface.withOpacity(0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextField(
                                controller: controller,
                                decoration: const InputDecoration.collapsed(
                                  hintText: 'Input Prompt Here',
                                ),
                                maxLines: 6,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Consumer(builder: (context, ref, child) {
                                    return TextButton(
                                      onPressed: () => submit(ref),
                                      child: Row(
                                        children: [
                                          if (loading)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8),
                                              child: SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          const Text('Generate'),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Name')),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: onSurface.withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Text(name.isEmpty
                                    ? 'Will auto generated after submit'
                                    : name),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Description')),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: onSurface.withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Text(description.isEmpty
                                    ? 'Will auto generated after submit'
                                    : description),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Tags')),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: onSurface.withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Text(tags.isEmpty
                                    ? 'Will auto generated after submit'
                                    : tags.join(', ')),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Consumer(builder: (context, ref, child) {
                            return ElevatedButton(
                              onPressed: () => store(ref),
                              child: const Text('Save'),
                            );
                          }),
                        )
                      ],
                    ),
                  ),
                ),
                const _Placeholder(),
              ],
            ),
          ),
          const _Placeholder(),
        ],
      ),
    );
  }

  void submit(WidgetRef ref) async {
    if (controller.text.isEmpty) return;
    setState(() {
      loading = true;
    });
    try {
      final setting = await ref.read(settingNotifierProvider.future);
      final sentinel =
          await SentinelApi().generate(controller.text, model: setting.model);

      setState(() {
        avatar = sentinel.avatar;
        name = sentinel.name;
        description = sentinel.description;
        tags = sentinel.tags;
        loading = false;
      });
    } catch (error) {
      setState(() {
        loading = false;
      });
    }
  }

  void store(WidgetRef ref) async {
    if (controller.text.isEmpty) return;
    final notifier = ref.read(sentinelsNotifierProvider.notifier);
    final sentinel = Sentinel()
      ..avatar = avatar
      ..description = description
      ..name = name
      ..prompt = controller.text
      ..tags = tags;
    notifier.store(sentinel);
    Navigator.of(context).pop();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(context),
        child: const SizedBox.expand(),
      ),
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).pop();
  }
}
