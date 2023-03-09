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
        title: Text(chat.title ?? '', overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemBuilder: (context, index) =>
                  ChatTile(message: chat.messages.reversed.elementAt(index)),
              itemCount: chat.messages.length,
              padding: const EdgeInsets.all(16),
              reverse: true,
            ),
          ),
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
                        onTapOutside: (event) =>
                            FocusScope.of(context).unfocus(),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      onPressed: () =>
                          handleSubmitted(textEditingController.text),
                      child: const Icon(Icons.send_outlined),
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
    final trimmedValue = value.trim().replaceAll('\n', '');
    if (trimmedValue.isEmpty) return;
    final message = Message()
      ..role = 'user'
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..content = trimmedValue;
    setState(() {
      chat.title = chat.title ?? trimmedValue;
      chat.messages.add(message);
    });
    textEditingController.clear();
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
      final dio = await ref.read(dioEmitter);
      final setting = await ref.read(settingEmitter);
      final messages = chat.messages
          .where(
              (message) => message.role != 'error' && message.createdAt != null)
          .map((message) => {'role': message.role, 'content': message.content})
          .toList();
      var content = '';
      var response = await dio.post(setting.url, data: {
        "model": setting.model,
        "messages": messages,
        "stream": true,
      });
      final Stream<List<int>> stream = response.data.stream;
      stream.listen((codeUnits) {
        final decodedMessage = utf8.decode(codeUnits);
        final regExp = RegExp(r'"delta":{"content":[\s\S]*?}');
        final matches = regExp.allMatches(decodedMessage);
        if (matches.isNotEmpty) {
          final choices = matches.elementAt(0).group(0);
          final decodedJson = json.decode('{$choices}');
          content += decodedJson['delta']['content'];
          setState(() {
            chat.messages.last.role = 'assistant';
            chat.messages.last.content = content;
            chat.messages.last.createdAt =
                DateTime.now().millisecondsSinceEpoch;
          });
          storeChat();
        }
      });
    } on DioError catch (error) {
      var content = error.type.toString();
      if (error.type == DioErrorType.unknown) {
        content = error.error.toString();
      }
      Response? response = error.response;
      if (response != null) {
        Stream<List<int>> stream = error.response?.data.stream;
        final codeUnits = await stream.first;
        final decodedJson = json.decode(utf8.decode(codeUnits));
        content = decodedJson['error']['message'];
      }
      final message = Message()
        ..role = 'error'
        ..content = content
        ..createdAt = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        chat.messages.last = message;
      });
      storeChat();
    } catch (error) {
      logger.e(error);
      final message = Message()
        ..role = 'error'
        ..content = error.toString()
        ..createdAt = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        chat.messages.last = message;
      });
      storeChat();
    } finally {
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
                  ? Theme.of(context).colorScheme.secondaryContainer
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
                  ? Theme.of(context).colorScheme.primaryContainer
                  : message.role == 'assistant'
                      ? Theme.of(context).colorScheme.secondaryContainer
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
                if (message.createdAt != null)
                  SelectableText(message.content ?? ''),
                if (message.createdAt == null)
                  const CircularProgressIndicator.adaptive(),
              ],
            ),
          ),
        ),
        if (message.role == 'user')
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
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
