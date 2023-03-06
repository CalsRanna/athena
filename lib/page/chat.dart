import 'dart:async';
import 'dart:convert';

import 'package:athena/creator/global.dart';
import 'package:athena/creator/setting.dart';
import 'package:athena/model/chat.dart';
import 'package:athena/page/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  List<Message> messages = [];
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
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator.adaptive(),
            if (loading) const SizedBox(width: 8),
            const Text('Athena'),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          controller: scrollController,
          itemBuilder: (context, index) => ChatTile(message: messages[index]),
          itemCount: messages.length,
          padding: const EdgeInsets.all(16),
          reverse: true,
        ),
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16.0,
                ),
              ),
              onPressed: loading
                  ? null
                  : () => handleSubmitted(textEditingController.text),
              child: const Icon(Icons.send_outlined),
            )
          ],
        ),
      ),
      floatingActionButton: showFloatingActionButton
          ? FloatingActionButton.small(
              shape: const CircleBorder(),
              onPressed: scrollToBottom,
              child: const Icon(Icons.arrow_downward_outlined),
            )
          : null,
    );
  }

  void handleClear() {
    showDialog(
      builder: (context) => AlertDialog(
        title: const Text('是否清空对话'),
        actions: [
          ElevatedButton(onPressed: cancelClear, child: const Text('否')),
          ElevatedButton(onPressed: confirmClear, child: const Text('是'))
        ],
      ),
      context: context,
    );
  }

  void cancelClear() {
    Navigator.of(context).pop();
  }

  void confirmClear() {
    setState(() {
      messages.clear();
      showFloatingActionButton = false;
    });
    Navigator.of(context).pop();
  }

  void navigateSettingPage() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const SettingPage()));
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
        chat.messages?.add(message);
      });
    } catch (error) {
      Logger().e(error);
    }
    await fetchResponse();
  }

  Future<void> fetchResponse() async {
    setState(() => loading = true);
    final logger = Logger();
    final ref = context.ref;
    final messages = chat.messages
        ?.map((message) => {'role': message.role, 'content': message.content})
        .toList();
    try {
      var content = '';
      final dio = ref.watch(dioEmitter.asyncData).data;
      final setting = ref.read(settingEmitter.asyncData).data!;
      var response = await dio?.post(setting.url, data: {
        "model": setting.model,
        "messages": messages?.toString(),
        "stream": true,
      });
      // ResponseBody data = response?.data;
      Stream<List<int>> stream = response?.data.stream;
      stream.every(
        (codeUnits) {
          try {
            final message = utf8.decode(codeUnits);
            logger.e(message);
            final decodedJson = json.decode('{$message}');
            final role = decodedJson['data']['choices'][0]['delta']['role'] ??
                'assistant';
            content +=
                decodedJson['data']['choices'][0]['delta']['content'] ?? '';
            messages?.last = {'role': role, 'content': content};
          } catch (error) {
            logger.e(error);
            content += '❎';
            messages?.last = {'role': 'assistant', 'content': content};
          }
          return true;
        },
      );
    } on DioError catch (error) {
      messages?.add({
        'role': 'system',
        'content': error.message ?? error.type.toString()
      });
    } catch (error) {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        ),
      );
    } finally {
      setState(() {});
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
        if (message.role == 'assistant')
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
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
                  : Theme.of(context).colorScheme.primaryContainer,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 2),
                Text(message.content ?? ''),
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
