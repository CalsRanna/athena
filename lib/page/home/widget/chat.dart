import 'package:athena/creator/chat.dart';
import 'package:athena/model/chat.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  @override
  Widget build(BuildContext context) {
    return EmitterWatcher<List<Chat>?>(
      emitter: chatsEmitter,
      builder: (context, chats) => ListView.builder(
        itemCount: chats?.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(chats?[index].title ?? ''),
        ),
      ),
    );
  }
}
