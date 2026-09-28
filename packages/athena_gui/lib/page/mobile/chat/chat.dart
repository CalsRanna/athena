import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/mobile/chat/component/chat_bottom_sheet.dart';
import 'package:athena_gui/component/message_list_scroll_controller.dart';
import 'package:athena_gui/component/queued_messages.dart';
import 'package:athena_gui/page/mobile/chat/component/message_list_view.dart';
import 'package:athena_gui/component/sentinel_placeholder.dart';
import 'package:athena_gui/page/mobile/chat/component/user_input.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/error_boundary.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatPage extends StatefulWidget {
  final ChatEntity? chat;
  final SentinelEntity? sentinel;

  const MobileChatPage({super.key, this.chat, this.sentinel});

  @override
  State<MobileChatPage> createState() => _MobileChatPageState();
}

class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();
  final scrollController = MessageListScrollController();

  /// 新对话页打开时 ViewModel 的当前对话（上一次打开的那条）。
  ///
  /// 进入草稿态（[ChatViewModel.prepareNewChatDraft]）要等模型与角色两段
  /// IO 之后，这段时间 currentChat 仍是它：不能显示它的消息，也不能把输入
  /// 发进它里面。见 [_resolveChat]。
  ChatEntity? _openedFrom;

  /// 新对话页还没进入草稿态。只在这段窗口内把 [_openedFrom] 当草稿看待；
  /// 之后当前对话再切回它（如被显式选中）就照常显示。
  bool _draftPending = false;

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  late final providerViewModel = GetIt.instance<ProviderViewModel>();

  @override
  Widget build(BuildContext context) {
    var actionButton = AthenaIconButton(
      icon: LucideIcons.ellipsis,
      onTap: () {
        openBottomSheet(_resolveChat());
      },
    );

    return AthenaScaffold(
      appBar: AthenaAppBar(action: actionButton, title: _buildTitle()),
      body: AthenaErrorBoundary(
        message: 'Chat page encountered an error',
        onRetry: _initializeViewModels,
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var chat = _resolveChat();
      var isRenaming =
          chat != null &&
          viewModel.selection.renamingChatIds.value.contains(chat.id);
      String title;
      if (isRenaming && viewModel.selection.renamingTitle.value.isNotEmpty) {
        title = viewModel.selection.renamingTitle.value;
      } else {
        title = chat?.title ?? 'New Chat';
        if (title.isEmpty) title = 'New Chat';
      }

      if (isRenaming) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(title, textAlign: TextAlign.center)),
            SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textPrimary,
              ),
            ),
          ],
        );
      }
      return Text(title, textAlign: TextAlign.center);
    });
  }

  Widget _buildContent() {
    return Watch((context) {
      var chat = _resolveChat();
      var sentinel = _resolveSentinel(chat);

      if (chat != null) {
        var model = modelViewModel.models.value
            .where((m) => m.id == chat.modelId)
            .firstOrNull;
        return MessageListView(
          key: ValueKey(chat.id),
          chat: chat,
          viewModel: viewModel,
          sentinelViewModel: sentinelViewModel,
          controller: scrollController,
          model: model,
          onChatTitleChanged: (_) {},
        );
      }
      return SentinelPlaceholder(sentinel: sentinel);
    });
  }

  ChatEntity? _resolveChat() {
    final requestedChat = widget.chat;
    final currentChat = viewModel.currentChat.value;
    if (requestedChat == null) {
      // 新对话页：还没切到草稿态时 currentChat 是来源对话，按草稿处理；
      // 首条消息建出的新对话 id 不同，照常显示
      if (_draftPending && currentChat?.id == _openedFrom?.id) return null;
      return currentChat;
    }
    if (currentChat?.id != requestedChat.id) {
      return viewModel.chats.value
              .where((chat) => chat.id == requestedChat.id)
              .firstOrNull ??
          requestedChat;
    }
    return currentChat;
  }

  SentinelEntity? _resolveSentinel(ChatEntity? chat) {
    if (chat != null && !chat.hasSentinel) {
      return SentinelViewModel.directChatSentinel;
    }
    SentinelEntity? sentinel;
    if (chat != null) {
      sentinel = sentinelViewModel.sentinels.value
          .where((s) => s.id == chat.sentinelId)
          .firstOrNull;
    } else {
      sentinel = sentinelViewModel.defaultSentinel.value;
    }
    sentinel ??= viewModel.currentSentinel.value;
    sentinel ??= sentinelViewModel.defaultSentinel.value;
    return sentinel;
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.chat == null) {
      _openedFrom = viewModel.currentChat.value;
      _draftPending = true;
    }
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    try {
      await modelViewModel.initSignals();
      await sentinelViewModel.getSentinels();
      if (widget.chat != null) {
        await viewModel.selectChat(widget.chat!);
      } else {
        // 上面两段 IO 期间用户可能已经发出首条消息、建好了新对话：不能再把
        // 它卸掉回草稿
        if (viewModel.currentChat.value?.id != _openedFrom?.id) return;
        // 移动端没有侧栏选中态，"当前对话"就是最近打开的那条；工作文件夹在
        // 移动端没有作用（不注册 shell / 文件工具），所以只继承角色。
        await viewModel.prepareNewChatDraft(
          inheritFrom: _openedFrom,
          inheritWorkspace: false,
        );
        // 入口注入的专属 Sentinel：作为新聊天的角色
        if (widget.sentinel != null) {
          viewModel.updateCurrentSentinel(widget.sentinel!);
        }
      }
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load chat. Please try again.');
      }
    } finally {
      if (mounted && _draftPending) setState(() => _draftPending = false);
    }
  }

  void openBottomSheet(ChatEntity? chat) {
    var mobileChatBottomSheet = MobileChatBottomSheet(
      chat: chat,
      chatViewModel: viewModel,
      sentinelViewModel: sentinelViewModel,
      modelViewModel: modelViewModel,
      providerViewModel: providerViewModel,
      onRetentionChanged: (value) => updateRetention(value),
      onModelChanged: (model) => updateModel(model),
      onSentinelChanged: (sentinel) => updateSentinel(sentinel),
      onTemperatureChanged: (value) => updateTemperature(value),
      onReasoningEffortChanged: (value) => updateReasoningEffort(value),
    );
    AthenaDialog.show(mobileChatBottomSheet);
  }

  Future<void> sendMessage(ChatEntity? chat) async {
    final text = controller.text;
    if (text.isEmpty) return;

    if (chat == null) {
      chat = await viewModel.createChat();
      if (chat == null) return;
    }

    controller.clear();
    scrollController.followBottom();

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: '',
    );

    await viewModel.sendMessage(message, chat: chat);
  }

  void terminateStreaming() {
    final chat = viewModel.currentChat.value;
    if (chat != null) viewModel.stopGenerating(chat.id!);
  }

  Future<void> updateRetention(int value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateRetention(value, chat: chat);
    } else {
      viewModel.updateCurrentRetention(value);
    }
  }

  Future<void> updateModel(ModelEntity model) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateModel(model, chat: chat);
    } else {
      await viewModel.updateCurrentModel(model);
    }
  }

  Future<void> updateSentinel(SentinelEntity sentinel) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateSentinel(sentinel, chat: chat);
    } else {
      viewModel.updateCurrentSentinel(sentinel);
    }
  }

  Future<void> updateTemperature(double value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateTemperature(value, chat: chat);
    } else {
      viewModel.updateCurrentTemperature(value);
    }
  }

  Future<void> updateReasoningEffort(String value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateReasoningEffort(value, chat: chat);
    } else {
      viewModel.updateCurrentReasoningEffort(value);
    }
  }

  Widget _buildInput() {
    return Watch((context) {
      final chat = _resolveChat();
      var userInput = UserInput(
        controller: controller,
        isStreaming: viewModel.isCurrentChatStreaming.value,
        onSubmitted: () => sendMessage(chat),
        onTerminated: terminateStreaming,
      );
      final queued = viewModel.queuedMessages.value;
      final padding = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (queued.isNotEmpty) ...[
              QueuedMessages(messages: queued),
              const SizedBox(height: 12),
            ],
            userInput,
          ],
        ),
      );
      return SafeArea(top: false, child: padding);
    });
  }
}
