import 'dart:async';

import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/page/mobile/chat/component/edit_message_dialog.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/message.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar/isar.dart';

@RoutePage()
class MobileChatPage extends ConsumerStatefulWidget {
  final Chat chat;
  const MobileChatPage({super.key, required this.chat});

  @override
  ConsumerState<MobileChatPage> createState() => _MobileChatPageState();
}

class _MessageListView extends ConsumerStatefulWidget {
  final Chat chat;
  final Model? model;
  final void Function(String)? onChatTitleChanged;
  const _MessageListView({
    required this.chat,
    this.model,
    this.onChatTitleChanged,
  });

  @override
  ConsumerState<_MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends ConsumerState<_MessageListView> {
  final controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    var provider = messagesNotifierProvider(widget.chat.id);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      _ => const SizedBox(),
    };
  }

  void destroyMessage(Message message) {
    var viewModel = ChatViewModel(ref);
    viewModel.destroyMessage(message);
    ADialog.dismiss();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void editMessage(Message message) {
    var viewModel = ChatViewModel(ref);
    viewModel.editMessage(message);
  }

  void openBottomSheet(Message message) {
    HapticFeedback.heavyImpact();
    var editTile = ABottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () => openEditDialog(message),
    );
    var deleteTile = ABottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyMessage(message),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    ADialog.show(SafeArea(child: padding));
  }

  void openEditDialog(Message message) {
    ADialog.dismiss();
    var dialog = MobileEditMessageDialog(
      message: message,
      onSubmitted: editMessage,
    );
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (_) => dialog,
      isScrollControlled: true,
    );
  }

  Future<void> resendMessage(WidgetRef ref, Message message) async {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    var viewModel = ChatViewModel(ref);
    viewModel.resendMessage(message, chat: widget.chat, model: widget.model);
    if (widget.chat.title.isEmpty || widget.chat.title == 'New Chat') {
      var title = await viewModel.renameChat(widget.chat);
      widget.onChatTitleChanged?.call(title);
    }
  }

  Widget _buildData(WidgetRef ref, List<Message> messages) {
    if (messages.isEmpty) return const SizedBox();
    final reversedMessages = messages.reversed.toList();
    return ListView.separated(
      controller: controller,
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
      onLongPress: () => openBottomSheet(message),
      onResend: () => resendMessage(ref, message),
    );
  }
}

class _MobileChatPageState extends ConsumerState<MobileChatPage> {
  final controller = TextEditingController();
  Model? model;

  late final viewModel = ChatViewModel(ref);
  late String title = widget.chat.title;

  @override
  Widget build(BuildContext context) {
    var input = _buildInput();
    var messages = ref.watch(messagesNotifierProvider(widget.chat.id)).value;
    var sentinel =
        ref.watch(sentinelNotifierProvider(widget.chat.sentinelId)).value;
    var columnChildren = [
      if (messages != null && messages.isEmpty)
        Expanded(child: _SentinelPlaceholder(sentinel: sentinel)),
      if (messages != null && messages.isNotEmpty)
        Expanded(
          child: _MessageListView(
            chat: widget.chat,
            model: model,
            onChatTitleChanged: updateTitle,
          ),
        ),
      input,
    ];
    var actionButton = AIconButton(
      icon: HugeIcons.strokeRoundedMoreHorizontal,
      onTap: openModalSelector,
    );
    var titleColumn = Column(
      children: [Text(title), _ModelIndicator(model: model)],
    );
    return AScaffold(
      appBar: AAppBar(action: actionButton, title: titleColumn),
      body: Column(children: columnChildren),
    );
  }

  void changeModel(Model model) {
    var viewModel = ChatViewModel(ref);
    viewModel.selectModel(model, chat: widget.chat);
    ADialog.dismiss();
    setState(() {
      this.model = model;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  void openModalSelector() {
    ADialog.show(MobileModelSelectDialog(onTap: changeModel));
  }

  Future<void> sendMessage(WidgetRef ref) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    await viewModel.sendMessage(text, chat: widget.chat, model: model);
    if (title.isEmpty || title == 'New Chat') {
      var title = await viewModel.renameChat(widget.chat);
      setState(() {
        this.title = title;
      });
    }
  }

  void updateTitle(String title) {
    setState(() {
      this.title = title;
    });
  }

  Widget _buildInput() {
    var userInput = _UserInput(
      controller: controller,
      onSubmitted: sendMessage,
    );
    final inputChildren = [
      Expanded(child: userInput),
      const SizedBox(width: 16),
      _SendButton(onTap: sendMessage),
    ];
    final row = Padding(
      padding: EdgeInsets.all(16),
      child: Row(children: inputChildren),
    );
    return SafeArea(top: false, child: row);
  }

  Future<void> _initModel() async {
    var builder = isar.models.filter().idEqualTo(widget.chat.modelId);
    var model = await builder.findFirst();
    setState(() {
      this.model = model;
    });
  }
}

class _ModelIndicator extends ConsumerWidget {
  final Model? model;
  const _ModelIndicator({this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (model == null) return const SizedBox();
    var provider = providerNotifierProvider(model!.providerId);
    var value = ref.watch(provider).valueOrNull;
    var text = Text(
      '${model!.name} | ${value?.name ?? ""}',
      style: TextStyle(color: Colors.white, fontSize: 14),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: Color(0xFF161616),
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: text,
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
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

class _UserInput extends ConsumerWidget {
  final TextEditingController controller;
  final void Function(WidgetRef)? onSubmitted;
  const _UserInput({required this.controller, this.onSubmitted});

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
