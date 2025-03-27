import 'dart:async';

import 'package:athena/component/message_list_tile.dart';
import 'package:athena/page/mobile/chat/component/chat_bottom_sheet.dart';
import 'package:athena/page/mobile/chat/component/edit_message_dialog.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
  final void Function(Chat)? onChatTitleChanged;
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

  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var sentinelProvider = sentinelNotifierProvider(widget.chat.sentinelId);
    var sentinel = ref.watch(sentinelProvider).value;
    if (sentinel == null) return const SizedBox();
    var messagesProvider = messagesNotifierProvider(widget.chat.id);
    var messages = ref.watch(messagesProvider).value;
    if (messages == null) return _SentinelPlaceholder(sentinel: sentinel);
    if (messages.isEmpty) return _SentinelPlaceholder(sentinel: sentinel);
    final reversedMessages = messages.reversed.toList();
    return ListView.separated(
      controller: controller,
      itemBuilder: (_, index) =>
          _itemBuilder(reversedMessages[index], sentinel),
      itemCount: messages.length,
      padding: EdgeInsets.symmetric(horizontal: 16),
      reverse: true,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }

  void destroyMessage(Message message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.destroyMessage(message);
    AthenaDialog.dismiss();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void editMessage(Message message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.editMessage(message);
  }

  void openBottomSheet(Message message) {
    HapticFeedback.heavyImpact();
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () => openEditDialog(message),
    );
    var deleteTile = AthenaBottomSheetTile(
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
    AthenaDialog.show(SafeArea(child: padding));
  }

  void openEditDialog(Message message) {
    AthenaDialog.dismiss();
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

  Future<void> resendMessage(Message message) async {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.resendMessage(message, chat: widget.chat);
    if (widget.chat.title.isEmpty || widget.chat.title == 'New Chat') {
      var renamedChat = await viewModel.renameChat(widget.chat);
      widget.onChatTitleChanged?.call(renamedChat);
    }
  }

  Widget _itemBuilder(Message message, Sentinel sentinel) {
    var loading = ref.watch(streamingNotifierProvider);
    return MessageListTile(
      loading: loading,
      message: message,
      onLongPress: () => openBottomSheet(message),
      onResend: () => resendMessage(message),
      sentinel: sentinel,
    );
  }
}

class _MobileChatPageState extends ConsumerState<MobileChatPage> {
  final controller = TextEditingController();

  late final viewModel = ChatViewModel(ref);
  late String title = widget.chat.title;

  late int _sentinelId = widget.chat.sentinelId;
  late int _modelId = widget.chat.modelId;
  late bool _enableSearch = widget.chat.enableSearch;
  late double _temperature = widget.chat.temperature;
  late int _context = widget.chat.context;

  @override
  Widget build(BuildContext context) {
    var chat = ref.watch(chatNotifierProvider(widget.chat.id)).value;
    if (chat == null) return const SizedBox();
    var model = ref.watch(modelNotifierProvider(_modelId)).value;
    var actionButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedMoreHorizontal,
      onTap: openBottomSheet,
    );
    var titleText = Text(title, textAlign: TextAlign.center);
    var messageListView = _MessageListView(
      chat: chat,
      model: model,
      onChatTitleChanged: updateTitle,
    );
    var input = _buildInput();
    return AthenaScaffold(
      appBar: AthenaAppBar(action: actionButton, title: titleText),
      body: Column(children: [Expanded(child: messageListView), input]),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  void openBottomSheet() {
    var copiedModel = widget.chat.copyWith(
      enableSearch: _enableSearch,
      modelId: _modelId,
      sentinelId: _sentinelId,
      temperature: _temperature,
      context: _context,
    );
    var mobileChatBottomSheet = MobileChatBottomSheet(
      chat: copiedModel,
      onContextChanged: updateContext,
      onEnableSearchChanged: updateEnableSearch,
      onModelChanged: updateModel,
      onSentinelChanged: updateSentinel,
      onTemperatureChanged: updateTemperature,
    );
    AthenaDialog.show(mobileChatBottomSheet);
  }

  Future<void> sendMessage(WidgetRef ref) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();
    await viewModel.sendMessage(text, chat: widget.chat);
    if (title.isEmpty || title == 'New Chat') {
      var renameChat = await viewModel.renameChat(widget.chat);
      setState(() {
        title = renameChat.title;
      });
    }
  }

  void terminateStreaming(WidgetRef ref) {
    var viewModel = ChatViewModel(ref);
    viewModel.terminateStreaming(widget.chat);
    setState(() {});
  }

  void updateContext(int value) {
    viewModel.updateContext(value, chat: widget.chat);
    setState(() {
      _context = value;
    });
  }

  void updateEnableSearch(bool value) {
    viewModel.updateEnableSearch(value, chat: widget.chat);
    setState(() {
      _enableSearch = value;
    });
  }

  void updateModel(Model model) {
    var viewModel = ChatViewModel(ref);
    viewModel.updateModel(model, chat: widget.chat);
    setState(() {
      _modelId = model.id;
    });
  }

  void updateSentinel(Sentinel sentinel) {
    var viewModel = ChatViewModel(ref);
    viewModel.updateSentinel(sentinel, chat: widget.chat);
    setState(() {
      _sentinelId = sentinel.id;
    });
  }

  void updateTemperature(double value) {
    viewModel.updateTemperature(value, chat: widget.chat);
    setState(() {
      _temperature = value;
    });
  }

  void updateTitle(Chat chat) {
    setState(() {
      title = chat.title;
    });
  }

  Widget _buildInput() {
    var userInput = _UserInput(
      controller: controller,
      onSubmitted: sendMessage,
    );
    var sendButton = _SendButton(
      onSubmitted: sendMessage,
      onTerminated: terminateStreaming,
    );
    final inputChildren = [
      Expanded(child: userInput),
      const SizedBox(width: 16),
      sendButton,
    ];
    final row = Padding(
      padding: EdgeInsets.all(16),
      child: Row(children: inputChildren),
    );
    return SafeArea(top: false, child: row);
  }
}

class _SendButton extends ConsumerWidget {
  final void Function(WidgetRef)? onSubmitted;
  final void Function(WidgetRef)? onTerminated;
  const _SendButton({this.onSubmitted, this.onTerminated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: StadiumBorder(),
      shadows: [boxShadow],
    );
    final streaming = ref.watch(streamingNotifierProvider);
    var iconData = HugeIcons.strokeRoundedSent;
    if (streaming) iconData = HugeIcons.strokeRoundedStop;
    var icon = Icon(iconData, color: ColorUtil.FF161616);
    var container = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: icon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: container,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) {
    var viewModel = ChatViewModel(ref);
    if (!viewModel.streaming) {
      onSubmitted?.call(ref);
      return;
    }
    onTerminated?.call(ref);
  }
}

class _SentinelPlaceholder extends ConsumerWidget {
  final Sentinel? sentinel;
  const _SentinelPlaceholder({required this.sentinel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const nameTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    const descriptionTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
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
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const inputDecoration = InputDecoration.collapsed(
      hintText: 'Send a message',
      hintStyle: hintTextStyle,
    );
    const textStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final textField = TextField(
      controller: controller,
      cursorColor: ColorUtil.FFFFFFFF,
      decoration: inputDecoration,
      onSubmitted: (_) => handleSubmitted(context, ref),
      onTapOutside: (_) => handleTapOutside(context),
      style: textStyle,
      textInputAction: TextInputAction.send,
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      shape: StadiumBorder(),
    );
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: textField,
    );
  }

  void handleSubmitted(BuildContext context, WidgetRef ref) {
    if (controller.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    var viewModel = ChatViewModel(ref);
    if (viewModel.streaming) return;
    onSubmitted?.call(ref);
  }

  void handleTapOutside(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
