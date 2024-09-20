import 'package:athena/provider/setting.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class APIUrlPage extends ConsumerStatefulWidget {
  const APIUrlPage({super.key});

  @override
  ConsumerState<APIUrlPage> createState() => _APIUrlPageState();
}

class _APIUrlPageState extends ConsumerState<APIUrlPage> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initState();
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = AIconButton(
      icon: HugeIcons.strokeRoundedTick02,
      onTap: handleTap,
    );
    return AScaffold(
      appBar: AAppBar(action: button, title: const Text('API Proxy Url')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          decoration:
              const InputDecoration.collapsed(hintText: 'API Proxy Url'),
          focusNode: focusNode,
          maxLines: null,
          style: const TextStyle(color: Color(0xffffffff)),
        ),
      ),
    );
  }

  Future<void> handleTap() async {
    if (controller.text.isNotEmpty) {
      final notifier = ref.read(settingNotifierProvider.notifier);
      notifier.updateUrl(controller.text);
    }
    Navigator.of(context).pop();
  }

  Future<void> _initState() async {
    final setting = await ref.read(settingNotifierProvider.future);
    controller.text = setting.url;
  }
}
