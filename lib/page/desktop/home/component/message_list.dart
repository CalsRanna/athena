import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopMessageList extends ConsumerWidget {
  final Chat? chat;
  final Model model;
  final Sentinel sentinel;
  const DesktopMessageList({
    super.key,
    this.chat,
    required this.model,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = messagesNotifierProvider(chat?.id ?? 0);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(WidgetRef ref, List<Message> messages) {
    if (messages.isEmpty == true) return const SizedBox();
    return ListView.separated(
      itemBuilder: (_, index) => _itemBuilder(ref, messages, index),
      itemCount: messages.length,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(WidgetRef ref, List<Message> messages, int index) {
    final message = messages.reversed.elementAt(index);
    return MessageTile(
      message: message,
      onResend: () => _resend(ref, message),
    );
  }

  Future<void> _resend(WidgetRef ref, Message message) async {
    final provider = chatNotifierProvider(chat?.id ?? 0);
    final notifier = ref.read(provider.notifier);
    await notifier.resend(message, model: model, sentinel: sentinel);
  }
}
