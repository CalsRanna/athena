import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/mobile/chat/component/chat_bottom_sheet.dart';
import 'package:athena_gui/page/mobile/chat/component/message_list_view.dart';
import 'package:athena_gui/page/mobile/chat/component/sentinel_placeholder.dart';
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
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileChatPage extends StatefulWidget {
  final ChatEntity? chat;
  final SentinelEntity? sentinel;

  /// 从 Shortcut 发起：本次会话的 Agent run 声明 JSON 输出。
  final bool jsonMode;
  const MobileChatPage({
    super.key,
    this.chat,
    this.sentinel,
    this.jsonMode = false,
  });

  @override
  State<MobileChatPage> createState() => _MobileChatPageState();
}

class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  late final providerViewModel = GetIt.instance<ProviderViewModel>();

  @override
  Widget build(BuildContext context) {
    var actionButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedMoreHorizontal,
      onTap: () {
        final chat = viewModel.currentChat.value ?? widget.chat;
        openBottomSheet(chat);
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
          chat: chat,
          viewModel: viewModel,
          sentinelViewModel: sentinelViewModel,
          model: model,
          onChatTitleChanged: (_) {},
        );
      }
      return SentinelPlaceholder(sentinel: sentinel);
    });
  }

  ChatEntity? _resolveChat() {
    ChatEntity? chat = viewModel.currentChat.value;
    if (chat == null && widget.chat != null) {
      chat = viewModel.chats.value
          .where((c) => c.id == widget.chat!.id)
          .firstOrNull;
    }
    return chat;
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeViewModels();
  }

  Future<void> _initializeViewModels() async {
    try {
      await modelViewModel.initSignals();
      await sentinelViewModel.getSentinels();
      if (widget.chat != null) {
        await viewModel.selectChat(widget.chat!);
      } else {
        await viewModel.prepareNewChatDraft();
        // Shortcut 入口：注入绑定的专属 Sentinel，作为新聊天的角色
        if (widget.sentinel != null) {
          viewModel.updateCurrentSentinel(widget.sentinel!);
        }
      }
    } catch (e) {
      if (mounted) {
        AthenaDialog.error('Failed to load chat. Please try again.');
      }
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

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: '',
    );

    await viewModel.sendMessage(message, chat: chat, jsonMode: widget.jsonMode);
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

  Future<void> updateReasoningEffort(String? value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateReasoningEffort(value, chat: chat);
    } else {
      viewModel.updateCurrentReasoningEffort(value);
    }
  }

  Widget _buildInput() {
    return Watch((context) {
      final chat = viewModel.currentChat.value ?? widget.chat;
      var userInput = UserInput(
        controller: controller,
        isStreaming: viewModel.isCurrentChatStreaming.value,
        onSubmitted: () => sendMessage(chat),
        onTerminated: terminateStreaming,
      );
      final padding = Padding(padding: EdgeInsets.all(16), child: userInput);
      return SafeArea(top: false, child: padding);
    });
  }
}
