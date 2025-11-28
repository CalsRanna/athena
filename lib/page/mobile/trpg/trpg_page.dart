import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/trpg_message_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/trpg_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/markdown.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileTRPGPage extends StatefulWidget {
  const MobileTRPGPage({super.key});

  @override
  State<MobileTRPGPage> createState() => _MobileTRPGPageState();
}

enum TRPGPageState { init, playing }

class _MobileTRPGPageState extends State<MobileTRPGPage> {
  final viewModel = GetIt.instance<TRPGViewModel>();
  final pageState = signal(TRPGPageState.init);

  final inputController = TextEditingController();
  final scrollController = ScrollController();

  bool _isCreatingGame = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AthenaScaffold(
        appBar: _buildAppBar(),
        body: Watch((_) {
          return pageState.value == TRPGPageState.init
              ? _buildInitView()
              : _buildGameView();
        }),
      ),
    );
  }

  @override
  void dispose() {
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Widget _buildAppBar() {
    return AthenaAppBar(
      leading: const SizedBox.shrink(),
      action: Container(
        decoration: ShapeDecoration(
          color: ColorUtil.FFFFFFFF,
          shape: StadiumBorder(),
        ),
        padding: EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(HugeIcons.strokeRoundedMoreHorizontal, size: 16),
            SizedBox(
              height: 12,
              child: VerticalDivider(
                thickness: 1,
                color: ColorUtil.FF757575,
                indent: 0,
                endIndent: 0,
                width: 1,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(HugeIcons.strokeRoundedCancel01, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitView() {
    return Center(
      child: GestureDetector(
        onTap: _isCreatingGame ? null : _handleStartGame,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          decoration: BoxDecoration(
            color: _isCreatingGame ? ColorUtil.FF757575 : ColorUtil.FFFFFFFF,
            borderRadius: BorderRadius.circular(32),
          ),
          child: _isCreatingGame
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorUtil.FF282828,
                  ),
                )
              : Text(
                  'START GAME',
                  style: TextStyle(
                    color: ColorUtil.FF282828,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  void _handleStartGame() async {
    if (_isCreatingGame) return;

    setState(() => _isCreatingGame = true);
    pageState.value = TRPGPageState.playing;

    viewModel.createNewGame().then((_) {
      setState(() => _isCreatingGame = false);
    });
  }

  Widget _buildDMMessageBubble(TRPGMessageEntity message, bool isStreaming) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Container(
          constraints: BoxConstraints(minWidth: double.infinity),
          decoration: BoxDecoration(
            color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.content.isNotEmpty)
                AthenaMarkdown(
                  message: MessageEntity(
                    chatId: 0,
                    role: 'assistant',
                    content: message.content,
                  ),
                ),
              if (isStreaming)
                Padding(
                  padding: EdgeInsets.only(
                    top: message.content.isEmpty ? 0 : 8,
                  ),
                  child: SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                ),
            ],
          ),
        ),
        if (!isStreaming)
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: message.suggestions.length + 1,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == message.suggestions.length) {
                  return _buildSomethingElseButton();
                }
                return _buildSuggestionButton(message.suggestions[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGameView() {
    return Column(
      children: [
        Expanded(child: _buildMessageList()),
        _buildInputPanel(),
      ],
    );
  }

  Widget _buildSuggestionButton(String suggestion) {
    return _buildActionButton(
      text: suggestion,
      onTap: () {
        inputController.text = suggestion;
        _handleSendMessage();
      },
    );
  }

  Widget _buildSomethingElseButton() {
    return _buildActionButton(
      text: 'Something else...',
      onTap: () {
        viewModel.showInputPanel.value = true;
      },
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
  }) {
    // 内层容器：深色背景
    final innerContainer = Container(
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: ColorUtil.FF161616,
        shape: StadiumBorder(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          color: ColorUtil.FFFFFFFF,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    // 外层容器：渐变边框效果
    final colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      Colors.transparent,
    ];
    final linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: StadiumBorder(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: shapeDecoration,
        padding: EdgeInsets.all(1),
        child: innerContainer,
      ),
    );
  }

  Widget _buildInputPanel() {
    return Watch((_) {
      final showInput = viewModel.showInputPanel.value;

      // 如果不显示输入框，返回空组件
      if (!showInput) return SizedBox.shrink();

      return _buildInputPanelContent();
    });
  }

  Widget _buildInputPanelContent() {
    final inputField = Container(
      decoration: ShapeDecoration(
        color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
        shape: StadiumBorder(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextField(
        controller: inputController,
        style: TextStyle(
          color: ColorUtil.FFF5F5F5,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: ColorUtil.FFFFFFFF,
        decoration: InputDecoration.collapsed(
          hintText: 'What will you do?',
          hintStyle: TextStyle(
            color: ColorUtil.FFC2C2C2,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        onSubmitted: (_) => _handleSendOrStop(),
        textInputAction: TextInputAction.send,
      ),
    );

    final sendButton = Watch((_) {
      final isStreaming = viewModel.isStreaming.value;
      final iconData = isStreaming
          ? HugeIcons.strokeRoundedStop
          : HugeIcons.strokeRoundedSent;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleSendOrStop,
        child: Container(
          decoration: ShapeDecoration(
            color: ColorUtil.FFFFFFFF,
            shape: StadiumBorder(),
            shadows: [
              BoxShadow(
                blurRadius: 16,
                color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Icon(iconData, color: ColorUtil.FF161616),
        ),
      );
    });

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: inputField),
            SizedBox(width: 16),
            sendButton,
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Watch((_) {
      final messages = viewModel.messages.value;
      final streamingMessage = viewModel.streamingMessage.value;
      final isStreaming = viewModel.isStreaming.value;

      final reversedMessages = messages.reversed.toList();
      return ListView.separated(
        controller: scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: messages.length + (isStreaming ? 1 : 0),
        reverse: true,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (isStreaming && index == 0) {
            if (streamingMessage != null) {
              return _buildDMMessageBubble(streamingMessage, true);
            }
            // streamingMessage 为空时显示加载指示器
            return Container(
              constraints: BoxConstraints(minWidth: double.infinity),
              decoration: BoxDecoration(
                color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 12,
                width: 12,
                child: CircularProgressIndicator(strokeWidth: 1),
              ),
            );
          }
          final messageIndex = isStreaming ? index - 1 : index;
          final message = reversedMessages[messageIndex];
          if (message.role == 'dm') {
            return _buildDMMessageBubble(message, false);
          }
          return _buildPlayerMessageBubble(message);
        },
      );
    });
  }

  Widget _buildPlayerMessageBubble(TRPGMessageEntity message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.centerLeft,
            constraints: BoxConstraints(minHeight: 36),
            child: Text(
              message.content,
              style: TextStyle(color: ColorUtil.FFCACACA, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _resendMessage(message),
          child: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ColorUtil.FFFFFFFF,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HugeIcons.strokeRoundedRefresh,
              size: 12,
              color: ColorUtil.FF282828,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    inputController.clear();
    viewModel.showInputPanel.value = false; // 发送后隐藏输入框
    await viewModel.sendPlayerAction(text);
  }

  void _handleSendOrStop() {
    if (viewModel.isStreaming.value) {
      // 停止当前流式响应
      viewModel.isStreaming.value = false;
    } else {
      // 发送消息
      _handleSendMessage();
    }
  }

  Future<void> _resendMessage(TRPGMessageEntity message) async {
    // 滚动到顶部（最新消息）
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        curve: Curves.linear,
        duration: Duration(milliseconds: 300),
      );
    }
    // 删除并重发消息
    await viewModel.deleteMessage(message);
    await viewModel.sendPlayerAction(message.content);
  }
}
