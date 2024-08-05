import 'dart:async';

import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:athena/service/model_provider.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

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
