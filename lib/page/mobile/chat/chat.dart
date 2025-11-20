import 'dart:async';

import 'package:athena/component/message_list_tile.dart';
import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/mobile/chat/component/chat_bottom_sheet.dart';
import 'package:athena/page/mobile/chat/component/edit_message_dialog.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatPage extends StatefulWidget {
  final ChatEntity chat;
  const MobileChatPage({super.key, required this.chat});

  @override
  State<MobileChatPage> createState() => _MobileChatPageState();
}

class _MessageListView extends StatefulWidget {
  final ChatEntity chat;
  final ModelEntity? model;
  final void Function(ChatEntity)? onChatTitleChanged;
  const _MessageListView({
    required this.chat,
    this.model,
    this.onChatTitleChanged,
  });

  @override
  State<_MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<_MessageListView> {
  final controller = ScrollController();

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.loadMessages(widget.chat.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinel = sentinelViewModel.sentinels.value
          .where((s) => s.id == widget.chat.sentinelId)
          .firstOrNull;
      if (sentinel == null) return const SizedBox();

      var messages = viewModel.messages.value
          .where((m) => m.chatId == widget.chat.id)
          .toList();
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
    });
  }

  void destroyMessage(MessageEntity message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    viewModel.deleteMessage(message);
    AthenaDialog.dismiss();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void editMessage(MessageEntity message) {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    // Edit message by deleting from this message onwards, then user can resend
    viewModel.deleteMessage(message);
  }

  void openBottomSheet(MessageEntity message) {
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

  void openEditDialog(MessageEntity message) {
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

  Future<void> resendMessage(MessageEntity message) async {
    var duration = Duration(milliseconds: 300);
    if (controller.hasClients) {
      controller.animateTo(0, curve: Curves.linear, duration: duration);
    }
    await viewModel.deleteMessage(message);
    await viewModel.sendMessage(message, chat: widget.chat);
  }

  Widget _itemBuilder(MessageEntity message, SentinelEntity sentinel) {
    var loading = viewModel.isStreaming.value;
    return MessageListTile(
      loading: loading,
      message: message,
      onLongPress: () => openBottomSheet(message),
      onResend: () => resendMessage(message),
      sentinel: sentinel,
    );
  }
}

class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late String title = widget.chat.title;

  late int _sentinelId = widget.chat.sentinelId;
  late int _modelId = widget.chat.modelId;
  late bool _enableSearch = widget.chat.enableSearch;
  late double _temperature = widget.chat.temperature;
  late int _context = widget.chat.context;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var chat = viewModel.chats.value
          .where((c) => c.id == widget.chat.id)
          .firstOrNull;
      if (chat == null) return const SizedBox();

      var model = modelViewModel.models.value
          .where((m) => m.id == _modelId)
          .firstOrNull;

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
        body: Column(
          children: [
            Expanded(child: messageListView),
            input,
          ],
        ),
      );
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

  Future<void> sendMessage() async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();

    var message = MessageEntity(
      id: 0,
      chatId: widget.chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: '',
    );

    await viewModel.sendMessage(message, chat: widget.chat);
    if (title.isEmpty || title == 'New Chat') {
      var renamedChat = await viewModel.renameChat(widget.chat);
      if (renamedChat != null) {
        setState(() {
          title = renamedChat.title;
        });
      }
    }
  }

  void terminateStreaming() {
    viewModel.isStreaming.value = false;
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

  void updateModel(ModelEntity model) {
    viewModel.updateModel(model, chat: widget.chat);
    setState(() {
      _modelId = model.id ?? 0;
    });
  }

  void updateSentinel(SentinelEntity sentinel) {
    viewModel.updateSentinel(sentinel, chat: widget.chat);
    setState(() {
      _sentinelId = sentinel.id ?? 0;
    });
  }

  void updateTemperature(double value) {
    viewModel.updateTemperature(value, chat: widget.chat);
    setState(() {
      _temperature = value;
    });
  }

  void updateTitle(ChatEntity chat) {
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

class _SendButton extends StatelessWidget {
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  const _SendButton({this.onSubmitted, this.onTerminated});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var boxShadow = BoxShadow(
        blurRadius: 16,
        color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
      );
      var shapeDecoration = ShapeDecoration(
        color: ColorUtil.FFFFFFFF,
        shape: StadiumBorder(),
        shadows: [boxShadow],
      );
      final chatViewModel = GetIt.instance<ChatViewModel>();
      final streaming = chatViewModel.isStreaming.value;
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
        onTap: () => handleTap(context, streaming),
        child: container,
      );
    });
  }

  void handleTap(BuildContext context, bool streaming) {
    if (!streaming) {
      onSubmitted?.call();
      return;
    }
    onTerminated?.call();
  }
}

class _SentinelPlaceholder extends StatelessWidget {
  final SentinelEntity? sentinel;
  const _SentinelPlaceholder({required this.sentinel});

  @override
  Widget build(BuildContext context) {
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

class _UserInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function()? onSubmitted;
  const _UserInput({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
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
      onSubmitted: (_) => handleSubmitted(context),
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

  void handleSubmitted(BuildContext context) {
    if (controller.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    var viewModel = GetIt.instance<ChatViewModel>();
    if (viewModel.isStreaming.value) return;
    onSubmitted?.call();
  }

  void handleTapOutside(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
