import 'package:athena/page/desktop/home/component/input.dart';
import 'package:athena/page/desktop/home/component/message.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';

class WorkSpace extends StatelessWidget {
  final Chat? chat;
  final void Function(String)? onSubmitted;
  const WorkSpace({super.key, this.chat, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    var children = [
      Expanded(child: MessageList(chat: chat)),
      Input(onSubmitted: onSubmitted)
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    return Container(
      decoration: BoxDecoration(border: Border(left: borderSide)),
      child: column,
    );
  }
}
