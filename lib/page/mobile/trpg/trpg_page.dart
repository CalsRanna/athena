import 'package:athena/entity/chat_entity.dart';
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

enum TRPGPageState { init, playing }

@RoutePage()
class MobileTRPGPage extends StatefulWidget {
  const MobileTRPGPage({super.key});

  @override
  State<MobileTRPGPage> createState() => _MobileTRPGPageState();
}

class _MobileTRPGPageState extends State<MobileTRPGPage> {
  final viewModel = GetIt.instance<TRPGViewModel>();
  final pageState = signal(TRPGPageState.init);

  String? selectedGameStyle;
  String? selectedGameMode;
  final characterController = TextEditingController();

  final inputController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void dispose() {
    characterController.dispose();
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

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

  // ==================== 初始化界面 ====================
  Widget _buildInitView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 32,
        children: [
          _buildInitTitle(),
          _buildGameStyleSection(),
          _buildCharacterSection(),
          _buildGameModeSection(),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildInitTitle() {
    return Center(
      child: Column(
        spacing: 8,
        children: [
          Text(
            '🎮 创建新游戏',
            style: TextStyle(
              color: ColorUtil.FFFFFFFF,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '开启一场属于你的冒险',
            style: TextStyle(color: ColorUtil.FFE0E0E0, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          'Step 1: 选择剧本风格',
          style: TextStyle(
            color: ColorUtil.FFFFFFFF,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildOptionChip('中世纪奇幻', selectedGameStyle, (value) {
              setState(() => selectedGameStyle = value);
            }),
            _buildOptionChip('赛博朋克2077', selectedGameStyle, (value) {
              setState(() => selectedGameStyle = value);
            }),
            _buildOptionChip('克苏鲁神话', selectedGameStyle, (value) {
              setState(() => selectedGameStyle = value);
            }),
            _buildOptionChip('武侠修仙', selectedGameStyle, (value) {
              setState(() => selectedGameStyle = value);
            }),
            _buildOptionChip('末日废土', selectedGameStyle, (value) {
              setState(() => selectedGameStyle = value);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          'Step 2: 角色设定',
          style: TextStyle(
            color: ColorUtil.FFFFFFFF,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextField(
          controller: characterController,
          style: TextStyle(color: ColorUtil.FFFFFFFF),
          decoration: InputDecoration(
            hintText: '输入职业/特长（如：战士、法师、盗贼）',
            hintStyle: TextStyle(color: ColorUtil.FF757575),
            filled: true,
            fillColor: ColorUtil.FF616161,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () {
              characterController.text = '让AI随机生成';
            },
            child: Text(
              '或让AI随机生成',
              style: TextStyle(color: ColorUtil.FFE0E0E0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          'Step 3: 游戏基调',
          style: TextStyle(
            color: ColorUtil.FFFFFFFF,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildOptionChip('爽文模式 (简单)', selectedGameMode, (value) {
              setState(() => selectedGameMode = value);
            }),
            _buildOptionChip('硬核生存 (困难)', selectedGameMode, (value) {
              setState(() => selectedGameMode = value);
            }),
            _buildOptionChip('解谜悬疑 (策略)', selectedGameMode, (value) {
              setState(() => selectedGameMode = value);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionChip(
    String label,
    String? selectedValue,
    Function(String) onSelected,
  ) {
    final isSelected = selectedValue == label;
    return GestureDetector(
      onTap: () => onSelected(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ColorUtil.FFFFFFFF : ColorUtil.FF616161,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? ColorUtil.FF282828 : ColorUtil.FFFFFFFF,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
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
                  '开始冒险',
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

  bool _isCreatingGame = false;

  void _handleStartGame() async {
    if (_isCreatingGame) return; // 防止重复点击

    if (selectedGameStyle == null ||
        characterController.text.isEmpty ||
        selectedGameMode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请完成所有选项')));
      return;
    }

    setState(() => _isCreatingGame = true);

    // 立即切换到游戏界面
    pageState.value = TRPGPageState.playing;

    // 异步创建游戏和生成开场
    viewModel
        .createNewGame(
          gameStyle: selectedGameStyle!,
          characterClass: characterController.text,
          gameMode: selectedGameMode!,
        )
        .then((_) {
          setState(() => _isCreatingGame = false);
        });
  }

  Widget _buildGameView() {
    return Column(
      children: [
        Expanded(child: _buildMessageList()),
        _buildSuggestionsPanel(),
        _buildInputPanel(),
      ],
    );
  }

  Widget _buildMessageList() {
    return Watch((_) {
      final messages = viewModel.messages.value;
      final streamingContent = viewModel.streamingContent.value;
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
            return _buildDMMessageBubble(streamingContent, true);
          }
          final messageIndex = isStreaming ? index - 1 : index;
          final message = reversedMessages[messageIndex];
          if (message.role == 'dm') {
            return _buildDMMessageBubble(message.content, false);
          }
          return _buildPlayerMessageBubble(message);
        },
      );
    });
  }

  Widget _buildDMMessageBubble(String content, bool isStreaming) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.isNotEmpty)
                  AthenaMarkdown(
                    message: MessageEntity(
                      chatId: 0,
                      role: 'assistant',
                      content: content,
                    ),
                  ),
                if (isStreaming)
                  Padding(
                    padding: EdgeInsets.only(top: content.isEmpty ? 0 : 8),
                    child: SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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

  Widget _buildSuggestionsPanel() {
    return Watch((_) {
      final suggestions = viewModel.suggestedActions.value;

      if (suggestions.isEmpty) return SizedBox.shrink();

      return SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => SizedBox(width: 8),
          itemBuilder: (context, index) {
            return _buildSuggestionButton(suggestions[index]);
          },
        ),
      );
    });
  }

  Widget _buildSuggestionButton(suggestion) {
    // 内层容器：深色背景
    final innerContainer = Container(
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: ColorUtil.FF161616,
        shape: StadiumBorder(),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(suggestion.emoji, style: TextStyle(fontSize: 16)),
          Text(
            suggestion.text,
            style: TextStyle(
              color: ColorUtil.FFFFFFFF,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      onTap: () {
        inputController.text = suggestion.text;
        _handleSendMessage();
      },
      child: Container(
        decoration: shapeDecoration,
        padding: EdgeInsets.all(1),
        child: innerContainer,
      ),
    );
  }

  Widget _buildInputPanel() {
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
          hintText: '输入你的行动...',
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

  void _handleSendOrStop() {
    if (viewModel.isStreaming.value) {
      // 停止当前流式响应
      viewModel.isStreaming.value = false;
    } else {
      // 发送消息
      _handleSendMessage();
    }
  }

  void _handleSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    inputController.clear();
    await viewModel.sendPlayerAction(text);
  }
}
