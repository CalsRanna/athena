import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/mobile/chat/component/chat_bottom_sheet.dart';
import 'package:athena/page/mobile/chat/component/message_list_view.dart';
import 'package:athena/page/mobile/chat/component/sentinel_placeholder.dart';
import 'package:athena/page/mobile/chat/component/user_input.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/error_boundary.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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

class _MobileChatPageState extends State<MobileChatPage> {
  final controller = TextEditingController();

  late final viewModel = GetIt.instance<ChatViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  late final providerViewModel = GetIt.instance<ProviderViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      ChatEntity? chat = viewModel.currentChat.value;

      if (chat == null && widget.chat != null) {
        chat = viewModel.chats.value
            .where((c) => c.id == widget.chat!.id)
            .firstOrNull;
      }

      SentinelEntity? sentinel;
      if (chat != null) {
        sentinel = sentinelViewModel.sentinels.value
            .where((s) => s.id == chat!.sentinelId)
            .firstOrNull;
      } else {
        sentinel = sentinelViewModel.defaultSentinel.value;
      }
      sentinel ??= viewModel.currentSentinel.value;
      sentinel ??= sentinelViewModel.defaultSentinel.value;

      var isRenaming = chat != null &&
          viewModel.selection.renamingChatIds.value.contains(chat.id);
      String title;
      if (isRenaming && viewModel.selection.renamingTitle.value.isNotEmpty) {
        title = viewModel.selection.renamingTitle.value;
      } else {
        title = chat?.title ?? 'New Chat';
        if (title.isEmpty) title = 'New Chat';
      }

      var actionButton = AthenaIconButton(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        onTap: () => openBottomSheet(chat),
      );

      Widget titleWidget;
      if (isRenaming) {
        var loadingIndicator = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ColorUtil.FFFFFFFF,
          ),
        );
        titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(title, textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            loadingIndicator,
          ],
        );
      } else {
        titleWidget = Text(title, textAlign: TextAlign.center);
      }

      Widget content;
      if (chat != null) {
        var model = modelViewModel.models.value
            .where((m) => m.id == chat!.modelId)
            .firstOrNull;
        content = MessageListView(
          chat: chat,
          viewModel: viewModel,
          sentinelViewModel: sentinelViewModel,
          model: model,
          onChatTitleChanged: (_) {},
        );
      } else {
        content = SentinelPlaceholder(sentinel: sentinel);
      }

      var input = _buildInput(chat);
      return AthenaScaffold(
        appBar: AthenaAppBar(action: actionButton, title: titleWidget),
        body: AthenaErrorBoundary(
          message: 'Chat page encountered an error',
          onRetry: _initializeViewModels,
          child: Builder(
            builder: (context) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return Column(
                children: [
                  Expanded(child: content),
                  _buildProgressBar(),
                  input,
                  SizedBox(height: bottomInset),
                ],
              );
            },
          ),
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
  }

  Future<void> _initializeViewModels() async {
    await modelViewModel.initSignals();
    await sentinelViewModel.getSentinels();
    if (widget.chat != null) {
      await viewModel.selectChat(widget.chat!);
    } else {
      await viewModel.prepareNewChatDraft();
    }
  }

  void openBottomSheet(ChatEntity? chat) {
    var mobileChatBottomSheet = MobileChatBottomSheet(
      chat: chat,
      chatViewModel: viewModel,
      sentinelViewModel: sentinelViewModel,
      modelViewModel: modelViewModel,
      providerViewModel: providerViewModel,
      onContextChanged: (value) => updateContext(value),
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

    if (chat == null) {
      chat = await viewModel.createChat();
      if (chat == null) return;
    }

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
    viewModel.stopGenerating();
  }

  Future<void> updateContext(int value) async {
    final chat = viewModel.currentChat.value;
    if (chat != null) {
      await viewModel.updateContext(value, chat: chat);
    } else {
      viewModel.updateCurrentContext(value);
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

  Widget _buildProgressBar() {
    return Watch((context) {
      final iteration = viewModel.currentIteration.value;
      if (iteration <= 0) return const SizedBox();

      final toolName = viewModel.currentToolName.value ?? '';
      final text = toolName.isNotEmpty
          ? 'Step $iteration · $toolName'
          : 'Step $iteration';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(
            color: ColorUtil.FFC2C2C2,
            fontSize: 12,
          )),
        ]),
      );
    });
  }

  Widget _buildInput(ChatEntity? chat) {
    var userInput = UserInput(
      controller: controller,
      isStreaming: viewModel.isStreaming.value,
      onSubmitted: () => sendMessage(chat),
      onTerminated: terminateStreaming,
    );
    final padding = Padding(padding: EdgeInsets.all(16), child: userInput);
    return SafeArea(top: false, child: padding);
  }
}
