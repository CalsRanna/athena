import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopMessageList extends ConsumerWidget {
  final Chat chat;
  final ScrollController? controller;
  final void Function(Message message) onResend;
  final Sentinel sentinel;
  const DesktopMessageList({
    super.key,
    required this.chat,
    this.controller,
    required this.onResend,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = messagesNotifierProvider(chat.id);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Message> messages) {
    if (messages.isEmpty == true) {
      return DesktopSentinelPlaceholder(sentinel: sentinel);
    }
    return ListView.separated(
      controller: controller,
      itemBuilder: (_, index) => _itemBuilder(messages, index),
      itemCount: messages.length,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(List<Message> messages, int index) {
    final message = messages.reversed.elementAt(index);
    return MessageListTile(
      message: message,
      onResend: () => onResend.call(message),
    );
  }
}
