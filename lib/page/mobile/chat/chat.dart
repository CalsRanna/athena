import 'dart:async';

import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/message.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class ChatPage extends StatefulWidget {
  final Chat? chat;
  const ChatPage({super.key, this.chat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ActionButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _ActionButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedMoreHorizontal,
      color: Color(0xff000000),
    );
    const boxDecoration = BoxDecoration(
      color: Color(0xffffffff),
      shape: BoxShape.circle,
    );
    final button = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(8),
      child: hugeIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(ref),
      child: button,
    );
  }

  void handleTap(WidgetRef ref) {
    onTap?.call(ref);
  }
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  int? id;
  String? title;

  @override
  Widget build(BuildContext context) {
    final inputChildren = [
      Expanded(child: _Input(controller: controller, onSubmitted: sendMessage)),
      const SizedBox(width: 16),
      _SendButton(onTap: sendMessage),
    ];
    final mediaQuery = MediaQuery.of(context);
    final input = Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, mediaQuery.padding.bottom + 16),
      child: Row(children: inputChildren),
    );
    var columnChildren = [
      Expanded(child: _MessageListView(chatId: id ?? 0)),
      input
    ];
    return AScaffold(
      appBar: AAppBar(action: _ActionButton(), title: _ChatTitle(chatId: id)),
      body: Column(children: columnChildren),
    );
  }

  Future<void> destroyChat(WidgetRef ref) async {
    if (id == null) return;
    final notifier = ref.read(chatsNotifierProvider.notifier);
    await notifier.destroy(id!);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    id = widget.chat?.id;
    title = widget.chat?.title;
  }

  Future<void> sendMessage(WidgetRef ref) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    if (id == null) {
      var provider = chatNotifierProvider(0);
      var notifier = ref.read(provider.notifier);
      var id = await notifier.create(text);
      setState(() {
        this.id = id;
      });
    }
    var provider = chatNotifierProvider(id ?? 0);
    var notifier = ref.read(provider.notifier);
    notifier.send(text);
  }
}

class _ChatTitle extends ConsumerWidget {
  final int? chatId;
  const _ChatTitle({this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chatId == null) return const Text('');
    var provider = chatNotifierProvider(chatId!);
    var chat = ref.watch(provider).valueOrNull;
    return Text(chat?.title ?? '');
  }
}

class _Input extends ConsumerWidget {
  final TextEditingController controller;
  final void Function(WidgetRef)? onSubmitted;
  const _Input({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textField = TextField(
      controller: controller,
      decoration: const InputDecoration.collapsed(hintText: 'Send a message'),
      onSubmitted: (_) => handleSubmitted(ref),
      style: const TextStyle(color: Color(0xffffffff)),
      textInputAction: TextInputAction.send,
    );
    const innerDecoration = ShapeDecoration(
      color: Color(0xff000000),
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: textField,
    );
    final colors = [
      const Color(0xffffffff).withValues(alpha: 0.2),
      const Color(0xff333333),
    ];
    final linearGradient = LinearGradient(
      colors: colors,
      stops: const [0, 0.4],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(1),
      child: body,
    );
  }

  void handleSubmitted(WidgetRef ref) {
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onSubmitted?.call(ref);
  }
}

class _MessageListView extends ConsumerWidget {
  final int? chatId;
  const _MessageListView({this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chatId == null) return const SizedBox();
    var provider = messagesNotifierProvider(chatId!);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Message> chats) {
    if (chats.isEmpty) return const SizedBox();
    final reversedChats = chats.reversed.toList();
    return ListView.separated(
      controller: ScrollController(),
      itemBuilder: (_, index) => MessageTile(message: reversedChats[index]),
      itemCount: chats.length,
      padding: EdgeInsets.symmetric(horizontal: 16),
      reverse: true,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }
}

class _SendButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sendIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedSent,
      color: Color(0xffffffff),
    );
    const loading = CircularProgressIndicator.adaptive(
      backgroundColor: Color(0xffffffff),
    );
    const innerDecoration = ShapeDecoration(
      color: Color(0xff000000),
      shape: StadiumBorder(),
    );
    final streaming = ref.watch(streamingNotifierProvider);
    final body = Container(
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: streaming ? loading : sendIcon,
    );
    final colors = [
      const Color(0xffffffff).withValues(alpha: 0.2),
      const Color(0xff333333),
    ];
    final linearGradient = LinearGradient(
      colors: colors,
      stops: const [0, 0.4],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    final button = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(1),
      child: body,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: button,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onTap?.call(ref);
  }
}
