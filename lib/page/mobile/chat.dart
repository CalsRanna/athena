import 'dart:async';

import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:athena/service/model_provider.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
              loading ? '对方正在输入...' : '',
              overflow: TextOverflow.ellipsis,
            );
          }),
        ),
        body: _Messages());
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

class _Messages extends ConsumerWidget {
  const _Messages({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messagesNotifierProvider);
    return state.when(data: data, error: error, loading: loading);
  }

  Widget data(List<Message> chats) {
    if (chats.isEmpty) return const SizedBox();
    return ListView.separated(
      controller: ScrollController(),
      itemBuilder: (context, index) => _MessageTile(message: chats[index]),
      itemCount: chats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return Center(child: Text(error.toString()));
  }

  Widget loading() {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({super.key, required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Text(message.content);
  }
}
