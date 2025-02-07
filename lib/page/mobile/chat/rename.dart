import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileChatRenamePage extends ConsumerStatefulWidget {
  final Chat chat;
  const MobileChatRenamePage({super.key, required this.chat});

  @override
  ConsumerState<MobileChatRenamePage> createState() =>
      _MobileChatRenamePageState();
}

class _MobileChatRenamePageState extends ConsumerState<MobileChatRenamePage> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final button = AIconButton(
      icon: HugeIcons.strokeRoundedTick02,
      onTap: handleTap,
    );
    var textField = TextField(
      controller: controller,
      decoration: const InputDecoration.collapsed(hintText: 'Name of the chat'),
      focusNode: focusNode,
      maxLines: null,
      style: const TextStyle(color: Color(0xffffffff)),
    );
    return AScaffold(
      appBar: AAppBar(action: button, title: const Text('Rename Chat')),
      body: Padding(padding: const EdgeInsets.all(16), child: textField),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> handleTap() async {
    if (controller.text.isNotEmpty) {
      var provider = chatNotifierProvider(widget.chat.id);
      final notifier = ref.read(provider.notifier);
      notifier.updateTitle(controller.text);
    }
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    controller.text = widget.chat.title;
    focusNode.requestFocus();
  }
}
