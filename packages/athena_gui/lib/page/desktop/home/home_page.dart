import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/home_shortcuts.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/component/message_list.dart';
import 'package:athena_gui/page/desktop/home/component/model_selector.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_selector.dart';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';

import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  final controller = TextEditingController();

  /// 输入框里那段文字属于哪条对话；null 是还没落盘的"新对话"草稿槽（也是启动
  /// 时的状态）。composer 只有一个 controller，跨对话复用它，所以必须自己记着
  /// 文字归属于谁，切换时才能把它存回原地、把目标对话的草稿取出来。
  int? _composerKey;

  /// composer 输入框的焦点：新建对话、启动落到草稿页时把焦点放进去。
  final composerFocusNode = FocusNode(debugLabel: 'composer');
  final scrollController = MessageListScrollController();
  final chatViewModel = GetIt.instance<ChatViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  final settingViewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var children = [
        _buildLeftBar(context),
        Expanded(child: _buildWorkspace()),
      ];
      // 页级快捷键（⌘N / Ctrl+N 新建对话）包在最外层：设置页、对话框是压在
      // 首页之上的路由，它们打开时焦点不在这棵子树里，快捷键自然不生效。
      return DesktopHomeShortcuts(
        onNewChat: startNewChat,
        child: AthenaScaffold(
          appBar: _buildAppBar(context),
          body: Row(children: children),
        ),
      );
    });
  }

  /// 侧栏 "New chat" 与 ⌘N / Ctrl+N：进入草稿态（不落盘），焦点放到输入框。
  ///
  /// 对齐 Claude 桌面端：新对话只是一个空页面，会话文件与侧栏条目要等首条
  /// 消息发出去才有（见 [sendMessage] → `ChatViewModel.createChat`）。已经在
  /// 草稿态时不重置——用户可能已经在草稿上换了角色、贴了图、打了半句话——
  /// 但焦点照样放回输入框，这样在草稿页按快捷键也等于"回到输入框"。
  ///
  /// 从某条对话点进来时把它的角色与工作文件夹带进草稿（见
  /// `ChatViewModel.prepareNewChatDraft`）。先取快照：prepareNewChatDraft
  /// 一进去就会把 `currentChat` 置空。
  Future<void> startNewChat() async {
    final source = chatViewModel.currentChat.value;
    // 草稿槽的切换不能等到 await 回来：这段 IO 期间用户可能已经在输入框里
    // 打字，晚一步恢复出来的草稿会把刚敲进去的字冲掉（见 [_restoreComposerDraft]）
    final preparing = source == null
        ? null
        : chatViewModel.prepareNewChatDraft(inheritFrom: source);
    _restoreComposerDraft(null);
    await preparing;
    if (!mounted) return;
    composerFocusNode.requestFocus();
  }

  Future<void> batchDestroyChats(List<ChatEntity> chats) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete ${chats.length} chats?',
    );
    if (result == true) {
      scrollController.followBottom();
      await chatViewModel.deleteChats(chats);
    }
    chatViewModel.clearSelection();
    _syncComposerDraft();
  }

  Future<void> destroyChat(ChatEntity chat) async {
    var result = await AthenaDialog.confirm('Do you want to delete this chat?');
    if (result == true) {
      scrollController.followBottom();
      await chatViewModel.deleteChat(chat);
    }
    // 删掉的若正好是当前对话，ViewModel 会自动落到邻居：输入框跟着换成那条
    // 对话的草稿（被删的那条不再有槽位，见 [_restoreComposerDraft]）
    _syncComposerDraft();
  }

  @override
  void dispose() {
    controller.dispose();
    composerFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> manualRenameChat(ChatEntity chat) async {
    var title = await AthenaDialog.input(
      'Rename Chat',
      initialValue: chat.title,
    );
    if (title != null && title.isNotEmpty) {
      await chatViewModel.renameChatManually(chat, title);
    }
  }

  Future<void> resendMessage(MessageEntity message) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) return;
    // 当前对话正在流式时重发会先删消息再被 sendMessage 静默吞掉，直接拦截
    if (chatViewModel.isStreamingChat(chat.id!)) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
    scrollController.followBottom();
    await chatViewModel.deleteMessage(message);
    await chatViewModel.sendMessage(message, chat: chat);
  }

  /// 侧栏点选对话。先把草稿换过去，再让 ViewModel 去加载消息（不 await：换草稿
  /// 必须在同一帧内完成，理由见 [_restoreComposerDraft]）。
  void selectChat(ChatEntity chat) {
    unawaited(chatViewModel.selectChat(chat));
    _restoreComposerDraft(chat.id);
  }

  /// 把输入框内容对齐到 [key] 那条对话的草稿：当前文字存回它所属的对话，再取出
  /// [key] 的草稿填进输入框（null = 还没落盘的"新对话"槽）。
  ///
  /// 每个会换 `ChatViewModel.currentChat` 的入口都要调一次（侧栏选中、新建对话、
  /// 删除后自动落到邻居、首条消息把草稿落盘成对话），否则 A 里打的字会跟着串进
  /// B。切换要在**发出切换动作的同一帧内**做完：等 IO 回来再换，这段延迟里用户
  /// 敲进去的字会被恢复出来的草稿覆盖。
  void _restoreComposerDraft(int? key) {
    if (key == _composerKey) return;
    // 原对话已经被删掉就不再留草稿：那个槽再也回不去（chat id 不复用）
    if (_composerKey == null ||
        chatViewModel.chats.value.any((chat) => chat.id == _composerKey)) {
      chatViewModel.saveComposerDraft(_composerKey, controller.text);
    }
    _composerKey = key;
    final draft = chatViewModel.takeComposerDraft(key);
    controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  /// 按当前选中的对话对齐输入框：删除当前对话后自动落到邻居、首条消息把草稿
  /// 落盘成对话时用（这两种情况的目标对话事先不知道）。
  void _syncComposerDraft() =>
      _restoreComposerDraft(chatViewModel.currentChat.value?.id);

  Future<void> sendMessage() async {
    var text = controller.text.trim();
    if (text.isEmpty) return;

    // 检查是否有可用的模型
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.warning('You should enable a provider first');
      return;
    }

    // 草稿态：首条消息发送时才把草稿落盘成对话
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chat = await chatViewModel.createChat();
      if (chat == null) return;
      // 落盘后输入框这段文字（马上要发出去）改归这条新对话，免得下次新建对话
      // 又把刚发出的句子填回输入框
      _composerKey = chat.id;
    }

    // 检查当前聊天的模型是否有效
    var model = chatViewModel.currentModel.value;
    if (model == null || model.id! <= 0) {
      AthenaDialog.warning('You should select a model first');
      return;
    }

    controller.clear();
    scrollController.followBottom();
    var imageUrls = <String>[];
    var images = chatViewModel.pendingImages.value;
    for (var image in images) {
      var bytes = await File(image).readAsBytes();
      imageUrls.add(base64Encode(bytes));
    }

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: imageUrls.join(','),
    );
    chatViewModel.clearPendingImages();

    await chatViewModel.sendMessage(message, chat: chat);
  }

  void terminateStreaming() {
    final chat = chatViewModel.currentChat.value;
    if (chat != null) chatViewModel.stopGenerating(chat.id!);
  }

  Future<void> updateRetention(int retention) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentRetention(retention);
      return;
    }
    await chatViewModel.updateRetention(retention, chat: chat);
  }

  void updateImage(List<String> images) {
    chatViewModel.pendingImages.value = images;
  }

  Future<void> updateModel(ModelEntity newModel) async {
    var chat = chatViewModel.currentChat.value;
    if (chat != null) {
      // 有选中的对话，更新对话的模型
      await chatViewModel.updateModel(newModel, chat: chat);
    } else {
      // 没有选中对话，只更新当前状态
      await chatViewModel.updateCurrentModel(newModel);
    }
  }

  Future<void> updateSentinel(SentinelEntity newSentinel) async {
    var chat = chatViewModel.currentChat.value;
    if (chat != null) {
      // 有选中的对话，更新对话的哨兵
      await chatViewModel.updateSentinel(newSentinel, chat: chat);
    } else {
      // 没有选中对话，只更新当前状态
      chatViewModel.updateCurrentSentinel(newSentinel);
    }
  }

  Future<void> updateReasoningEffort(String effort) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentReasoningEffort(effort);
      return;
    }
    await chatViewModel.updateReasoningEffort(effort, chat: chat);
  }

  /// 清除本会话的 Sentinel，回到「不选择任何 Sentinel」（direct chat 假实体）。
  /// 没有选中对话时改的是草稿角色：下一次新建对话即不带 Sentinel。
  Future<void> clearSentinel() =>
      updateSentinel(SentinelViewModel.directChatSentinel);

  /// 选择本会话的工作文件夹（目录选择器在 ViewModel 层弹；取消不改变现状）。
  Future<void> pickWorkspaceFolder() => chatViewModel.pickWorkspaceFolder();

  /// 清除本会话的工作文件夹，回到默认（shell 用用户主目录）。
  /// 没有选中对话时改的是草稿：落盘时就不带工作文件夹。
  Future<void> clearWorkspaceFolder() async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentWorkspacePath(null);
      return;
    }
    await chatViewModel.updateWorkspacePath(null, chat: chat);
  }

  Widget _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // Claude 的顶栏**是有内容的**：左边是窗口控制与导航，中间是会话标题，
    // 右侧是一组视图操作。这里保留标题那一部分（Athena 没有导航与右面板）。
    var title = Watch((context) {
      final chat = chatViewModel.currentChat.value;
      final text = chat?.title.trim() ?? '';
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.isEmpty ? 'New chat' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AthenaTextStyle.section.copyWith(color: colors.textPrimary),
        ),
      );
    });
    return AthenaAppBar(
      title: Padding(padding: const EdgeInsets.only(left: 12), child: title),
    );
  }

  Widget _buildLeftBar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var chatListView = DesktopChatListView(
      onCreateChat: startNewChat,
      onAutoRenamed: chatViewModel.renameChat,
      onBatchDestroyed: batchDestroyChats,
      onDestroyed: destroyChat,
      onManualRenamed: manualRenameChat,
      onPinned: chatViewModel.togglePin,
      onSelected: selectChat,
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surfacePanel,
        // 外壳分隔线（侧栏右边界）：与顶栏里那段用同一档，见 app_bar.dart
        border: Border(right: BorderSide(color: colors.borderChrome)),
      ),
      height: double.infinity,
      width: AthenaSpace.sidebar,
      child: chatListView,
    );
  }

  Widget _buildWorkspace() {
    var workspace = DesktopMessageList(
      controller: scrollController,
      onResend: resendMessage,
    );
    var desktopMessageInput = DesktopMessageInput(
      controller: controller,
      focusNode: composerFocusNode,
      onRetentionChange: updateRetention,
      onImageSelected: updateImage,
      onImagePasted: chatViewModel.addPendingImage,
      onImageRemoved: chatViewModel.removePendingImage,
      onSubmitted: sendMessage,
      onReasoningEffortChange: updateReasoningEffort,
      onTerminated: terminateStreaming,
      onModelTap: _openModelSelector,
      onSentinelTap: _openSentinelSelector,
      onSentinelClear: clearSentinel,
      onWorkspaceTap: pickWorkspaceFolder,
      onWorkspaceClear: clearWorkspaceFolder,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: workspace),
        desktopMessageInput,
      ],
    );
  }

  Future<void> _initState() async {
    await settingViewModel.initSignals();
    await chatViewModel.initSignals();
    // 启动落在空草稿页，和点 New chat 一样把焦点放到输入框，开屏即可打字
    if (mounted) composerFocusNode.requestFocus();
    await modelViewModel.loadEnabledModels();
    await sentinelViewModel.getSentinels();
  }

  /// 在模型名那一块（[anchor]）上方弹出模型菜单。
  void _openModelSelector(Rect anchor) async {
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.warning('You should enable a provider first');
      return;
    }
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(
      context,
      DesktopModelSelectMenu(anchor: anchor, onSelected: updateModel),
    );
  }

  /// 在 Sentinel chip（[anchor]）上方弹出角色菜单。
  void _openSentinelSelector(Rect anchor) async {
    if (sentinelViewModel.sentinels.value.isEmpty) {
      await sentinelViewModel.getSentinels();
    }
    if (sentinelViewModel.sentinels.value.isEmpty) {
      AthenaDialog.warning('No sentinels found');
      return;
    }
    if (!mounted) return;
    DesktopContextMenuManager.instance.show(
      context,
      DesktopSentinelSelectMenu(anchor: anchor, onSelected: updateSentinel),
    );
  }
}
