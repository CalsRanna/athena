import 'dart:async';

import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/message.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar/isar.dart';

@RoutePage()
class MobileChatPage extends StatefulWidget {
  final Chat? chat;
  final Sentinel? sentinel;
  const MobileChatPage({super.key, this.chat, this.sentinel});

  @override
  State<MobileChatPage> createState() => _MobileChatPageState();
}

class _ActionButton extends ConsumerWidget {
  final int? chatId;
  final Model? model;
  final void Function(Model)? onChanged;
  const _ActionButton({this.chatId, this.model, this.onChanged});

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
    ADialog.show(
      _ActionDialog(chatId: chatId, model: model, onChanged: onChanged),
    );
  }
}

class _ActionDialog extends ConsumerWidget {
  final int? chatId;
  final Model? model;
  final void Function(Model)? onChanged;
  const _ActionDialog({this.chatId, this.model, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // var provider = modelsNotifierProvider;
    // var state = ref.watch(provider);
    // return switch (state) {
    //   AsyncData(:final value) => _buildData(context, ref, value),
    //   _ => const SizedBox(),
    // };
    return SizedBox();
  }

  void changeModel(Model model) {
    onChanged?.call(model);
    ADialog.dismiss();
  }

  Widget _buildData(BuildContext context, WidgetRef ref, List<Model> models) {
    if (models.isEmpty) return const SizedBox();
    var children = models.map(_itemBuilder).toList();
    var wrap = Wrap(
      alignment: WrapAlignment.start,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
    var bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottom + 12),
      width: double.infinity,
      child: wrap,
    );
  }

  Widget _itemBuilder(Model model) {
    return _ModelTile(
      model: model,
      modelOfChat: this.model,
      onTap: () => changeModel(model),
    );
  }
}

class _ModelTile extends ConsumerWidget {
  final Model model;
  final Model? modelOfChat;
  final void Function()? onTap;
  const _ModelTile({required this.model, this.modelOfChat, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selected = modelOfChat?.id == model.id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ATag(selected: selected, text: model.name),
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  final int? chatId;
  const _ChatTitle({this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = chatNotifierProvider(chatId ?? 0);
    var chat = ref.watch(provider).valueOrNull;
    var title = chat?.title ?? '';
    if (title.isEmpty) title = '新的对话';
    return Text(title);
  }
}

class _Input extends ConsumerWidget {
  final TextEditingController controller;
  final void Function(WidgetRef)? onSubmitted;
  const _Input({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hintTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    const textStyle = TextStyle(
      color: Color(0xFFF5F5F5),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textField = TextField(
      controller: controller,
      cursorColor: Colors.white,
      decoration: inputDecoration,
      onSubmitted: (_) => handleSubmitted(ref),
      onTapOutside: (_) => handleTapOutside(context),
      style: textStyle,
      textInputAction: TextInputAction.send,
    );
    var shapeDecoration = ShapeDecoration(
      color: Color(0xFFADADAD).withValues(alpha: 0.6),
      shape: StadiumBorder(),
    );
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: textField,
    );
  }

  void handleSubmitted(WidgetRef ref) {
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    if (controller.text.isEmpty) return;
    onSubmitted?.call(ref);
  }

  void handleTapOutside(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}

class _MessageListView extends ConsumerWidget {
  final int chatId;
  const _MessageListView({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = messagesNotifierProvider(chatId);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(WidgetRef ref, List<Message> messages) {
    if (messages.isEmpty) return const SizedBox();
    final reversedMessages = messages.reversed.toList();
    return ListView.separated(
      controller: ScrollController(),
      itemBuilder: (_, index) => _itemBuilder(ref, reversedMessages[index]),
      itemCount: messages.length,
      padding: EdgeInsets.symmetric(horizontal: 16),
      reverse: true,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  Widget _itemBuilder(WidgetRef ref, Message message) {
    return MessageListTile(
      message: message,
      onResend: () => _resend(ref, message),
    );
  }

  Future<void> _resend(WidgetRef ref, Message message) async {
    final provider = chatNotifierProvider(chatId);
    final notifier = ref.read(provider.notifier);
    // await notifier.resend(message);
  }
}

class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();
  int? id;
  Model? model;

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
      if (id == null)
        Expanded(child: _SentinelPlaceholder(sentinel: widget.sentinel)),
      if (id != null) Expanded(child: _MessageListView(chatId: id!)),
      input,
    ];
    var actionButton = _ActionButton(
      chatId: id,
      model: model,
      onChanged: changeModel,
    );
    var chatTitle = _ChatTitle(chatId: id);
    return AScaffold(
      appBar: AAppBar(action: actionButton, title: chatTitle),
      body: Column(children: columnChildren),
    );
  }

  void changeModel(Model model) {
    setState(() {
      this.model = model;
    });
    if (id == null) return;
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(id!);
    var notifier = container.read(provider.notifier);
    notifier.updateModel(model);
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
    _initModel();
  }

  Future<void> _initModel() async {
    var model = await isar.models
        .filter()
        .idEqualTo(widget.chat?.modelId ?? 0)
        .findFirst();
    setState(() {
      this.model = model;
    });
  }

  Future<void> sendMessage(WidgetRef ref) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    // if (id == null) {
    //   var provider = chatNotifierProvider(widget.chat?.id ?? 0);
    //   var notifier = ref.read(provider.notifier);
    //   var chatId = await notifier.create(sentinel: widget.sentinel);
    //   setState(() {
    //     id = chatId;
    //   });
    // }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var provider = chatNotifierProvider(id!);
      var notifier = ref.read(provider.notifier);
      // notifier.send(text);
    });
  }
}

class _SendButton extends ConsumerWidget {
  final void Function(WidgetRef)? onTap;
  const _SendButton({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: Color(0xFFCED2C7).withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: Colors.white,
      shape: StadiumBorder(),
      shadows: [boxShadow],
    );
    final streaming = ref.watch(streamingNotifierProvider);
    const loading = CircularProgressIndicator.adaptive(
      backgroundColor: Color(0xFF161616),
    );
    const sendIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedSent,
      color: Color(0xFF161616),
    );
    var container = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: streaming ? loading : sendIcon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: container,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    final streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    onTap?.call(ref);
  }
}

class _SentinelPlaceholder extends ConsumerWidget {
  final Sentinel? sentinel;
  const _SentinelPlaceholder({required this.sentinel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const nameTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    const descriptionTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var text = Text(
      sentinel?.name ?? '',
      style: nameTextStyle,
      textAlign: TextAlign.center,
    );
    var children = [
      text,
      const SizedBox(height: 36),
      Text(sentinel?.description ?? '', style: descriptionTextStyle),
    ];
    var column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    return Padding(padding: const EdgeInsets.all(16.0), child: column);
  }
}
