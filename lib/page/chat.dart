import 'dart:async';

import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:athena/service/model_provider.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.id});
  final int? id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController scrollController;

  bool loading = false;
  bool showFloatingActionButton = false;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          showFloatingActionButton =
              scrollController.position.extentBefore != 0;
        });
      });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatingActionButton = showFloatingActionButton
        ? Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: FloatingActionButton.small(
              shape: const CircleBorder(),
              onPressed: scrollToBottom,
              child: const Icon(Icons.arrow_downward_outlined),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Watcher((context, ref, child) {
          final chats = ref.watch(chatsCreator);
          final current = ref.watch(currentChatCreator) ?? 0;
          return Text(
            loading ? '对方正在输入...' : chats[current].title ?? '',
            overflow: TextOverflow.ellipsis,
          );
        }),
      ),
      body: Column(
        children: [
          // Expanded(
          //   child: Watcher((context, ref, child) {
          //     final chats = ref.watch(chatsCreator);
          //     final current = ref.watch(currentChatCreator) ?? 0;
          //     return ListView.builder(
          //       controller: scrollController,
          //       itemBuilder: (context, index) => ChatTile(
          //         message: chats[current].messages.reversed.elementAt(index),
          //         onDelete: () => handleDelete(index),
          //         onEdit: () => handleEdit(index),
          //         onRetry: () => handleRetry(index),
          //       ),
          //       itemCount: chats[current].messages.length,
          //       padding: const EdgeInsets.all(16),
          //       reverse: true,
          //     );
          //   }),
          // ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 3,
            surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Watcher((context, ref, child) {
                        final controller =
                            ref.watch(textEditingControllerCreator);
                        final node = ref.watch(focusNodeCreator);
                        return TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            hintText: 'Ask me anything...',
                            isCollapsed: false,
                            isDense: true,
                          ),
                          focusNode: node,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          scrollPadding: EdgeInsets.zero,
                          onSubmitted: handleSubmitted,
                          onTapOutside: (event) => node.unfocus(),
                        );
                      }),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      onPressed: selectModel,
                      icon: Icon(
                        Icons.send_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Future<void> handleDelete(int index) async {
    ChatProvider.of(context).delete(index);
  }

  void handleEdit(int index) {
    ChatProvider.of(context).edit(index);
  }

  Future<void> handleRetry(int index) async {
    ChatProvider.of(context).retry(index);
  }

  Future<void> handleSubmitted(String value) async {
    ChatProvider.of(context).submit();
  }

  void selectModel() {
    ChatProvider.of(context).submit();
  }

  Future<void> handleSelect(int index) async {
    final chats = context.ref.read(chatsCreator);
    final current = context.ref.read(currentChatCreator);
    if (current == null) return;
    final chat = chats[current];
    final models = ModelProvider.of(context).models;
    chat.model = models[index];
    context.ref.set(chatsCreator, [...chats]);
    final navigator = Navigator.of(context);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    navigator.pop();
  }

  void scrollToBottom() {
    Timer(const Duration(milliseconds: 16), () {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    });
  }
}

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.message,
    this.onDelete,
    this.onEdit,
    this.onRetry,
  });
  final Message message;
  final void Function()? onDelete;
  final void Function()? onEdit;
  final void Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondaryContainer = colorScheme.secondaryContainer;
    final errorContainer = colorScheme.errorContainer;
    final primaryContainer = colorScheme.primaryContainer;
    final secondary = colorScheme.secondary;
    final error = colorScheme.error;
    final textTheme = theme.textTheme;
    final labelSmall = textTheme.labelSmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: message.role == 'user'
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (message.role != 'user')
          Container(
            decoration: BoxDecoration(
              color: message.role == 'assistant'
                  ? secondaryContainer
                  : errorContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 8, top: 8),
            child: Image.asset(
              'asset/image/tray_512x512.jpg',
              color: Colors.black,
              width: 24,
            ),
          ),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: message.role == 'user'
                  ? primaryContainer
                  : message.role == 'assistant'
                      ? secondaryContainer
                      : errorContainer,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.content),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.role == 'user')
                      GestureDetector(
                        onTap: () => onEdit?.call(),
                        child: Text(
                          '编辑',
                          style: labelSmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                    if (message.role == 'user') const SizedBox(width: 4),
                    if (message.role == 'user')
                      GestureDetector(
                        onTap: () => onDelete?.call(),
                        child: Text(
                          '删除',
                          style: labelSmall?.copyWith(
                            color: error,
                          ),
                        ),
                      ),
                    if (message.role == 'user') const SizedBox(width: 4),
                    if (message.role != 'user')
                      GestureDetector(
                        onTap: () => onRetry?.call(),
                        child: Text(
                          '重新生成',
                          style: labelSmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                    if (message.role != 'user') const SizedBox(width: 4),
                    if (message.role != 'user')
                      GestureDetector(
                        onTap: () => copy(context, message),
                        child: Text(
                          '复制',
                          style: labelSmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      )
                  ],
                ),
              ],
            ),
          ),
        ),
        if (message.role == 'user')
          Container(
            decoration: BoxDecoration(
              color: primaryContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(left: 8, top: 8),
            child: const Icon(
              Icons.face_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
      ],
    );
  }

  void copy(BuildContext context, Message message) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: message.content));
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('已复制'),
        width: 75,
      ),
    );
  }
}
