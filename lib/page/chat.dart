import 'dart:async';
import 'dart:convert';

import 'package:athena/creator/chat.dart';
import 'package:athena/creator/global.dart';
import 'package:athena/creator/setting.dart';
import 'package:athena/model/chat.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.id});
  final int? id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController scrollController;
  late TextEditingController textEditingController;

  bool loading = false;
  bool showFloatingActionButton = false;
  Chat chat = Chat();

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
    textEditingController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    fetchChat();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatingActionButton = showFloatingActionButton
        ? FloatingActionButton.small(
            shape: const CircleBorder(),
            onPressed: scrollToBottom,
            child: const Icon(Icons.arrow_downward_outlined),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator.adaptive(),
            if (loading) const SizedBox(width: 8),
            Text(chat.title ?? ''),
          ],
        ),
      ),
      body: ListView.builder(
        controller: scrollController,
        itemBuilder: (context, index) =>
            ChatTile(message: chat.messages.reversed.elementAt(index)),
        itemCount: chat.messages.length,
        padding: const EdgeInsets.all(16),
        reverse: true,
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 12,
            right: 16,
            bottom: 48,
            left: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textEditingController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: 'Ask me anything...',
                    isCollapsed: false,
                    isDense: true,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  scrollPadding: EdgeInsets.zero,
                  onSubmitted: handleSubmitted,
                  onTapOutside: (event) => FocusScope.of(context).unfocus(),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12.0,
                  ),
                ),
                onPressed: () => handleSubmitted(textEditingController.text),
                child: const Icon(Icons.send_outlined),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  void fetchChat() async {
    if (widget.id != null) {
      final isar = await context.ref.read(isarEmitter);
      final exist = await isar.chats.get(widget.id!);
      setState(() {
        chat = exist?.withGrowableMessages() ?? Chat();
      });
    }
  }

  void handleSubmitted(String value) async {
    textEditingController.clear();
    if (value.trim().isEmpty) return;
    try {
      final message = Message()
        ..role = 'user'
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..content = value;
      setState(() {
        chat.title = value;
        chat.messages.add(message);
      });
    } catch (error) {
      Logger().e(error);
    }
    await fetchResponse();
  }

  Future<void> fetchResponse() async {
    setState(() {
      loading = true;
      chat.messages.add(Message()..role = 'assistant');
    });
    final logger = Logger();
    final ref = context.ref;
    try {
      final dio = await ref.watch(dioEmitter);
      final setting = await ref.read(settingEmitter);
      final messages = chat.messages
          .where(
              (message) => message.role != 'error' && message.createdAt != null)
          .map((message) => {'role': message.role, 'content': message.content})
          .toList();
      var content = '';
      var response = await dio.post(setting.url, data: {
        "model": setting.model,
        "messages": messages.toString(),
        "stream": true,
      });
      Stream<List<int>> stream = response.data.stream;
      await stream.every(
        (codeUnits) {
          try {
            final decodedContent = json.decode('{${utf8.decode(codeUnits)}}');
            final role = decodedContent['data']['choices'][0]['delta']
                    ['role'] ??
                'assistant';
            content +=
                decodedContent['data']['choices'][0]['delta']['content'] ?? '';
            setState(() {
              chat.messages.last.role = role;
              chat.messages.last.content = content;
              chat.messages.last.createdAt = chat.messages.last.createdAt ??
                  int.tryParse(decodedContent['data']['choices'][0]['delta']
                      ['content']) ??
                  0;
            });
          } catch (error) {
            logger.e(error);
            content += '❎';
            setState(() {
              chat.messages.last.content = content;
            });
          }
          return true;
        },
      );
    } on DioError catch (error) {
      logger.e(error);
      final message = Message()
        ..role = 'error'
        ..content = error.message ?? error.type.toString()
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      setState(() {
        chat.messages.last = message;
      });
    } catch (error) {
      logger.e(error);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          // padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        ),
      );
    } finally {
      storeChat();
      setState(() {
        loading = false;
      });
    }
  }

  void storeChat() async {
    try {
      final ref = context.ref;
      final isar = await ref.read(isarEmitter);
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
      });
      final chats = await isar.chats.where().findAll();
      ref.emit(chatsEmitter, chats);
    } catch (error) {
      Logger().e(error);
    }
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
  const ChatTile({super.key, required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
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
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 8, top: 8),
            child: const Icon(Icons.smart_toy_outlined),
          ),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: message.role == 'user'
                  ? Colors.greenAccent
                  : message.role == 'assistant'
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.createdAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 10,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(
                                message.createdAt ?? 0)
                            .toIso8601String()
                            .substring(11, 16),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                if (message.createdAt != null) const SizedBox(height: 2),
                if (message.createdAt != null) Text(message.content ?? ''),
                if (message.createdAt == null)
                  const CircularProgressIndicator.adaptive(),
              ],
            ),
          ),
        ),
        if (message.role == 'user')
          Container(
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(left: 8, top: 8),
            child: const Icon(Icons.face_outlined),
          ),
      ],
    );
  }
}
