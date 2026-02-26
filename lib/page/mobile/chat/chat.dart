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
  final ChatEntity? chat;
  final SentinelEntity? sentinel;
  const MobileChatPage({super.key, this.chat, this.sentinel});

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
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    await viewModel.refreshMessages(widget.chat.id!);
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

      var loading = viewModel.isStreaming.value;

      final reversedMessages = messages.reversed.toList();
      return ListView.separated(
        controller: controller,
        itemBuilder: (_, index) => _itemBuilder(
          reversedMessages[index],
          sentinel,
          loading && index == 0,
        ),
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

  Widget _itemBuilder(
    MessageEntity message,
    SentinelEntity sentinel,
    bool loading,
  ) {
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
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();

  // Track the current chat ID (null means new chat not yet created)
  int? _currentChatId;

  // Track selected sentinel for new chat (before creation)
  SentinelEntity? _selectedSentinel;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      // If we have a chat ID, find the chat from currentChat or chats list
      ChatEntity? chat;
      var currentChat = viewModel.currentChat.value;
      if (_currentChatId != null) {
        // Prefer currentChat if it matches (updated by renameChat)
        if (currentChat?.id == _currentChatId) {
          chat = currentChat;
        }
        chat ??= viewModel.chats.value
            .where((c) => c.id == _currentChatId)
            .firstOrNull;
      } else if (widget.chat != null) {
        if (currentChat?.id == widget.chat!.id) {
          chat = currentChat;
        }
        chat ??= viewModel.chats.value
            .where((c) => c.id == widget.chat!.id)
            .firstOrNull;
        if (chat != null) {
          _currentChatId = chat.id;
        }
      }

      // Get sentinel for placeholder
      SentinelEntity? sentinel = _selectedSentinel ?? widget.sentinel;
      if (sentinel == null && chat != null) {
        sentinel = sentinelViewModel.sentinels.value
            .where((s) => s.id == chat!.sentinelId)
            .firstOrNull;
      }
      // If no sentinel selected, use current sentinel from viewModel
      sentinel ??= viewModel.currentSentinel.value;
      sentinel ??= sentinelViewModel.sentinels.value.firstOrNull;

      // Build title
      String title = chat?.title ?? 'New Chat';
      if (title.isEmpty) title = 'New Chat';

      // Always show action button
      var actionButton = AthenaIconButton(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        onTap: () => openBottomSheet(chat),
      );

      var titleText = Text(title, textAlign: TextAlign.center);

      // Build message list or placeholder
      Widget content;
      if (chat != null) {
        var model = modelViewModel.models.value
            .where((m) => m.id == chat!.modelId)
            .firstOrNull;
        content = _MessageListView(
          chat: chat,
          model: model,
          onChatTitleChanged: (_) {},
        );
      } else {
        content = _SentinelPlaceholder(sentinel: sentinel);
      }

      var input = _buildInput(chat);
      return AthenaScaffold(
        appBar: AthenaAppBar(action: actionButton, title: titleText),
        body: Column(
          children: [
            Expanded(child: content),
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
    _initializeViewModels();
    // Initialize current chat ID if chat was passed
    if (widget.chat != null) {
      _currentChatId = widget.chat!.id;
    }
    // Initialize selected sentinel if passed
    _selectedSentinel = widget.sentinel;
  }

  Future<void> _initializeViewModels() async {
    await modelViewModel.initSignals();
    if (widget.chat != null) {
      await viewModel.selectChat(widget.chat!);
    }
  }

  void openBottomSheet(ChatEntity? chat) {
    var mobileChatBottomSheet = MobileChatBottomSheet(
      chat: chat,
      onContextChanged: (value) => updateContext(value),
      onEnableSearchChanged: (value) => updateEnableSearch(value),
      onModelChanged: (model) => updateModel(model),
      onSentinelChanged: (sentinel) => updateSentinel(sentinel),
      onTemperatureChanged: (value) => updateTemperature(value),
    );
    AthenaDialog.show(mobileChatBottomSheet);
  }

  Future<void> sendMessage(ChatEntity? chat) async {
    final text = controller.text;
    if (text.isEmpty) return;
    controller.clear();

    // If no chat exists, create one first
    if (chat == null) {
      chat = await viewModel.createChat(
        sentinel: _selectedSentinel ?? widget.sentinel,
      );
      if (chat == null) return;
      setState(() {
        _currentChatId = chat!.id;
      });
    }

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: '',
    );

    await viewModel.sendMessage(message, chat: chat);

    // Rename chat after first message
    if (chat.title.isEmpty || chat.title == 'New Chat') {
      await viewModel.renameChat(chat);
    }
  }

  void terminateStreaming() {
    viewModel.isStreaming.value = false;
  }

  ChatEntity? _getCurrentChat() {
    if (_currentChatId == null) return null;
    return viewModel.chats.value
        .where((c) => c.id == _currentChatId)
        .firstOrNull;
  }

  Future<void> updateContext(int value) async {
    var chat = _getCurrentChat();
    if (chat != null) {
      await viewModel.updateContext(value, chat: chat);
    }
  }

  Future<void> updateEnableSearch(bool value) async {
    var chat = _getCurrentChat();
    if (chat != null) {
      await viewModel.updateEnableSearch(value, chat: chat);
    }
  }

  Future<void> updateModel(ModelEntity model) async {
    var chat = _getCurrentChat();
    if (chat != null) {
      await viewModel.updateModel(model, chat: chat);
    } else {
      await viewModel.updateCurrentModel(model);
    }
  }

  Future<void> updateSentinel(SentinelEntity sentinel) async {
    var chat = _getCurrentChat();
    if (chat != null) {
      await viewModel.updateSentinel(sentinel, chat: chat);
    } else {
      setState(() {
        _selectedSentinel = sentinel;
      });
      viewModel.updateCurrentSentinel(sentinel);
    }
  }

  Future<void> updateTemperature(double value) async {
    var chat = _getCurrentChat();
    if (chat != null) {
      await viewModel.updateTemperature(value, chat: chat);
    }
  }

  Widget _buildInput(ChatEntity? chat) {
    var userInput = _UserInput(
      controller: controller,
      onSubmitted: () => sendMessage(chat),
      onTerminated: terminateStreaming,
    );
    final padding = Padding(padding: EdgeInsets.all(16), child: userInput);
    return SafeArea(top: false, child: padding);
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
      var icon = Icon(iconData, color: ColorUtil.FF161616, size: 16);
      var container = Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(12),
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
  final void Function()? onTerminated;
  const _UserInput({
    required this.controller,
    this.onSubmitted,
    this.onTerminated,
  });

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
      maxLines: 2,
      minLines: 2,
      onTapOutside: (_) => handleTapOutside(context),
      style: textStyle,
      textInputAction: TextInputAction.newline,
    );
    var sendButton = _SendButton(
      onSubmitted: onSubmitted,
      onTerminated: onTerminated,
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
    var rowChildren = [
      Expanded(child: textField),
      const SizedBox(width: 16),
      sendButton,
    ];
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }

  void handleTapOutside(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
