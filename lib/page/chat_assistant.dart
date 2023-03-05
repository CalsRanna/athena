import 'dart:async';
import 'dart:convert';

import 'package:athena/creator/global.dart';
import 'package:athena/page/setting.dart';
import 'package:creator/creator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ChatAssistant extends StatefulWidget {
  const ChatAssistant({super.key});

  @override
  State<ChatAssistant> createState() => _ChatAssistantState();
}

class _ChatAssistantState extends State<ChatAssistant> {
  static const secretKey =
      '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';
  static const model = 'gpt-3.5-turbo';
  static const url = 'https://api.openai.com/v1/chat/completions';

  late ScrollController scrollController;
  late TextEditingController controller;

  List<Message> messages = [];
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
    controller = TextEditingController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all_outlined),
            onPressed: handleClear,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: navigateSettingPage,
          ),
        ],
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
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ),
                child: ListView.builder(
                  controller: scrollController,
                  itemBuilder: (context, index) =>
                      ChatTile(message: messages[index]),
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Ask me anything...',
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: handleSubmitted,
                      onTapOutside: (event) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined),
                    onPressed: loading ? null : handleRefresh,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: showFloatingActionButton
          ? Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: FloatingActionButton.small(
                shape: const CircleBorder(),
                onPressed: scrollToBottom,
                child: const Icon(Icons.arrow_downward_outlined),
              ),
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
    controller.clear();
    if (value.trim().isEmpty) return;
    setState(() {
      messages.insert(
          0,
          Message(
            role: 'user',
            createdAt: DateTime.now().toIso8601String(),
            content: value,
          ));
      scrollToBottom();
    });
    var message = await fetchResponse();
    if (message != null) {
      setState(() {
        messages.insert(0, message);
        scrollToBottom();
      });
    }
  }

  Future<Message?> fetchResponse() async {
    try {
      setState(() {
        loading = true;
        messages.insert(
          0,
          Message(
            content: '...',
            createdAt: DateTime.now().toIso8601String(),
            role: 'assistant',
          ),
        );
      });
      final dio = context.ref.watch(dioEmitter.asyncData).data;
      var response = await dio?.post(
        url,
        data: {
          "model": model,
          "messages": messages
              .skip(1)
              .toList()
              .reversed
              .map((message) => message.toJson())
              .toList(),
          "stream": true,
        },
      );
      ResponseBody data = response?.data;
      var streamContent = '';
      data.stream.every(
        (codeUnits) {
          try {
            final message = utf8.decode(codeUnits);
            if (message.contains('[DONE]')) {
              setState(() {
                loading = false;
              });
            } else {
              final map = json.decode(message.replaceFirst('data: ', ''));
              streamContent += map['choices'][0]['delta']['content'] ?? '';
              setState(() {
                messages[0] = Message(
                  content: streamContent,
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                          (int.tryParse(map['created'].toString()) ?? 0) * 1000)
                      .toIso8601String(),
                  role: map['choices'][0]['delta']['role'] ?? 'assistant',
                );
              });
            }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
            );
            setState(() {
              loading = false;
            });
          }
          return true;
        },
      );
    } on DioError catch (error) {
      setState(() {
        messages[0] = Message(
          content: error.message ?? error.type.toString(),
          createdAt: DateTime.now().toIso8601String(),
          role: 'assistant',
        );
        loading = false;
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
      setState(() {
        loading = false;
      });
    }
    return null;
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

  void handleRefresh() async {
    scrollToBottom();
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '无需刷新',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ));
    } else {
      var message = await fetchResponse();
      if (message != null) {
        setState(() {
          messages.insert(0, message);
          scrollToBottom();
        });
      }
    }
  }
}

class Message {
  Message({required this.content, required this.createdAt, required this.role});

  String content;
  String createdAt;
  String role;

  Map<String, String> toJson() {
    return {'content': content, 'role': role};
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
                      message.createdAt.substring(11, 16),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message.content),
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
