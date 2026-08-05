import 'dart:async';

import 'package:athena_core/coordinator/agent_run_coordinator.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/text_util.dart';
import 'package:athena_tui/ui/widgets/command_suggestions.dart';
import 'package:athena_tui/ui/widgets/error_bar.dart';
import 'package:athena_tui/ui/widgets/input_area.dart';
import 'package:athena_tui/ui/widgets/message_list.dart';
import 'package:athena_tui/ui/widgets/permission_bar.dart';
import 'package:athena_tui/ui/widgets/picker_overlay.dart';
import 'package:athena_tui/ui/widgets/status_bar.dart';
import 'package:athena_tui/view_model/chat_controller.dart';
import 'package:nocterm/nocterm.dart';

/// Athena TUI 根组件:布局 + 全局按键 + 权限审批 + 命令处理。
class AthenaApp extends StatefulComponent {
  final TuiDi di;

  /// 消息列表滚动控制器;测试可注入以便模拟用户滚动(默认自建)。
  final ScrollController? scrollController;

  const AthenaApp({super.key, required this.di, this.scrollController});

  @override
  State<AthenaApp> createState() => _AthenaAppState();
}

class _AthenaAppState extends State<AthenaApp> {
  /// 全部斜杠命令(命令, 描述):帮助文本与实时建议的单一数据源。
  static const List<(String, String)> _allCommands = [
    ('/new', '新建聊天'),
    ('/list', '列出聊天'),
    ('/switch', '选择聊天'),
    ('/delete', '删除当前聊天'),
    ('/json', '以 JSON 模式运行 Agent(输出结构化 JSON)'),
    ('/model', '选择模型(仅显示已配置 API key 的)'),
    ('/sentinels', '选择角色'),
    ('/providers', '配置 Provider API key'),
    ('/help', '显示本帮助'),
    ('/quit', '退出'),
  ];
  static String get _helpText {
    // 行数须控制在消息区视口内(约 19 行):超出会被自动滚底裁掉标题。
    // 整条消息是一张卡片:nocterm 边框布局上下各占 1 行,故内容行数 +
    // 2(边框) + 1(列表底部留白) 须 ≤ 视口。当前 9 行内容装下有余量;
    // 新增命令/提示行时注意同步压缩。
    final commands = [
      '  /new 新建 · /list 列出 · /switch 切换',
      '  /delete 删除 · /json JSON 模式 · /model 模型',
      '  /sentinels 角色 · /providers 配置 Key · /help 帮助',
      '  /quit 退出',
    ].join('\n');
    return 'Athena TUI 命令:\n'
        '$commands\n'
        '\n'
        '快捷键:\n'
        '  Enter 发送 · Tab 补全 · Esc 停止/关闭\n'
        '  Ctrl+N 新建 · Ctrl+P 上一个 · Ctrl+M 模型 · Ctrl+S 角色';
  }

  late final ChatController _controller;
  late final ScrollController _scrollController;

  final _textController = TextEditingController();
  final List<void Function()> _disposers = [];

  // 权限 / Skill 信任审批请求(M3 模态)
  _PermissionRequest? _permissionRequest;

  _SkillTrustRequest? _skillTrustRequest;

  // 选择模态(模型 / 角色 / 聊天)
  _PickerState? _picker;

  // API key 输入模式:非 null 时输入区被用作 key 输入(仅 Esc 可退出)
  ProviderEntity? _keyInputProvider;

  /// 用户是否停留在消息列表底部(决定新消息是否自动滚底)。
  ///
  /// 不能用 `scrollController.atEnd` 的瞬时值判断:新消息追加后
  /// offset < maxScrollExtent 立即变 false,会漏掉"本来就在底部"的情况。
  /// 改为 sticky:用户上翻时置 false,滚回底部时置 true。
  bool _stickToBottom = true;

  /// 当前匹配输入的斜杠命令建议(实时过滤,输入以 `/` 开头时非空)。
  List<(String, String)> _commandSuggestions = const [];

  /// 命令建议是否可见:有匹配且不在任何模态(审批/选择/key 输入)中。
  bool get _showCommandSuggestions =>
      _commandSuggestions.isNotEmpty &&
      _permissionRequest == null &&
      _skillTrustRequest == null &&
      _picker == null &&
      _keyInputProvider == null;

  // ─── 构建 ────────────────────────────────────────────────

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _handleGlobalKey,
      // crossAxisAlignment.stretch:nocterm Flex 默认 center,消息列表
      // (内容宽 < 终端宽)会被水平居中;stretch 让子项撑满宽度后,
      // 列表内容按各自 Column 的 start 对齐,实现左对齐
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MessageList(
              controller: _controller,
              scrollController: _scrollController,
            ),
          ),
          ErrorBar(message: _controller.error.value),
          if (_permissionRequest != null)
            PermissionBar(
              title: '权限请求',
              detail:
                  '${_permissionRequest!.toolName}: '
                  '${_permissionRequest!.arguments}',
              hint: '[y] 允许  [n] 拒绝  [a] 总是允许',
            ),
          if (_skillTrustRequest != null)
            PermissionBar(
              title: '信任项目级 Skill',
              detail:
                  '${_skillTrustRequest!.dir}\n'
                  '${_skillTrustRequest!.names.join(', ')}',
              hint: '[y] 信任  [n] 拒绝',
            ),
          // 常驻组件:children 数量恒定,visible 控制显隐
          PickerOverlay(
            visible: _picker != null,
            title: _picker?.title ?? '',
            labels: _picker?.labels ?? const [],
            selectedIndex: _picker?.index ?? 0,
          ),
          // 斜杠命令实时建议:输入 / 开头时显示,紧贴输入区
          CommandSuggestions(
            visible: _showCommandSuggestions,
            commands: _commandSuggestions,
          ),
          InputArea(
            controller: _controller,
            textController: _textController,
            onSubmitted: _submit,
            placeholder: _keyInputProvider == null
                ? '输入消息…'
                : '为 ${_keyInputProvider!.name} 输入 API key…',
            statusText: _keyInputProvider == null
                ? ''
                : 'API key 输入中:回车保存 · 留空/ Esc 取消',
            onKeyEvent: (event) {
              // 审批模态(权限/Skill 信任):所有按键交给全局处理器
              // (y/n/a 决策)。必须返回其结果(true)—— 若返回 false,
              // TextField 内部会把 'y' 当作字符插入输入框,事件永远
              // 冒泡不到根 Focusable 的 _handleGlobalKey(审批无响应)。
              if (_permissionRequest != null || _skillTrustRequest != null) {
                return _handleGlobalKey(event);
              }
              // API key 输入模式:仅 Esc 退出,其余按键正常输入
              if (_keyInputProvider != null) {
                if (event.logicalKey == LogicalKey.escape) {
                  _textController.clear();
                  setState(() => _keyInputProvider = null);
                  _pushSystemMessage('已取消配置。');
                  return true;
                }
                return false;
              }
              // 模态期间:输入框让路给 picker(TextField 会先调本回调,
              // 返回 true 即拦截方向键,不移动光标)
              if (_picker != null) {
                return _handlePickerKey(event);
              }
              // 命令建议可见时:Tab 补全第一个匹配命令
              if (event.logicalKey == LogicalKey.tab &&
                  _commandSuggestions.isNotEmpty) {
                _completeCommand(_commandSuggestions.first.$1);
                return true;
              }
              // 输入框内按键:Esc 停止生成(其余由 TextField 处理/上抛)
              if (event.logicalKey == LogicalKey.escape &&
                  _controller.isStreaming.value) {
                _controller.stopGenerating();
                return true;
              }
              return false;
            },
          ),
          StatusBar(controller: _controller, workspace: component.di.workspace),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final dispose in _disposers) {
      dispose();
    }
    _textController.removeListener(_onInputChanged);
    // 注入的 controller 归调用方(测试)管理,只释放自建的
    if (component.scrollController == null) {
      _scrollController.dispose();
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = component.di.chatController;
    _scrollController = component.scrollController ?? ScrollController();

    // UI 层注册审批实现(bridge 在 UI 未就绪时拒绝请求)
    component.di.agentBridge.permissionHandler = _handlePermission;
    component.di.agentBridge.skillTrustHandler = _handleSkillTrust;

    _disposers.add(_controller.chatList.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentChat.subscribe((_) => _refresh()));
    _disposers.add(_controller.messages.subscribe((_) => _onMessagesChanged()));
    _disposers.add(_controller.currentModel.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentProvider.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentSentinel.subscribe((_) => _refresh()));
    _disposers.add(_controller.isStreaming.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentIteration.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentToolName.subscribe((_) => _refresh()));
    _disposers.add(_controller.currentTokenUsage.subscribe((_) => _refresh()));
    _disposers.add(_controller.error.subscribe((_) => _refresh()));

    _scrollController.addListener(_onScrollChanged);
    _textController.addListener(_onInputChanged);

    unawaited(_controller.initialize());
  }

  void _closePicker([int? result]) {
    final picker = _picker;
    if (picker == null) return;
    _picker = null;
    picker.completer.complete(result);
    setState(() {});
  }

  /// Tab 补全:用第一个匹配命令替换命令部分,保留已输入的参数,
  /// 光标移到命令末尾(方便继续输入参数)。
  void _completeCommand(String command) {
    final current = _textController.text;
    final spaceIndex = current.indexOf(' ');
    final rest = spaceIndex >= 0 ? current.substring(spaceIndex) : '';
    _textController
      ..text = command + rest
      ..selection = TextSelection.collapsed(offset: command.length);
  }

  Future<void> _handleCommand(String input) async {
    final parts = input.split(RegExp(r'\s+'));
    final command = parts[0];
    final args = input.substring(command.length).trim();

    switch (command) {
      case '/help':
        _pushSystemMessage(_helpText);
      case '/new':
        if (_streamingGuard()) return;
        await _controller.newChat();
      case '/list':
        final chats = _controller.chatList.value;
        if (chats.isEmpty) {
          _pushSystemMessage('暂无聊天。输入 /new 新建。');
        } else {
          _pushSystemMessage(
            chats
                .asMap()
                .entries
                .map((e) {
                  final c = e.value.chat;
                  final marker = c.id == _controller.currentChat.value?.id
                      ? '● '
                      : '  ';
                  return '$marker#${c.id} ${c.title}';
                })
                .join('\n'),
          );
        }
      case '/delete':
        if (_streamingGuard()) return;
        await _controller.deleteCurrentChat();
      case '/switch':
        if (_streamingGuard()) return;
        await _switchChatPicker();
      case '/model':
        await _pickModel();
      case '/sentinels':
        await _pickSentinel();
      case '/providers':
        await _manageProviders();
      case '/json':
        if (args.isEmpty) {
          _pushSystemMessage('用法:/json <文本> —— 以 JSON 模式运行 Agent。');
        } else {
          await _controller.sendMessage(args, jsonMode: true);
        }
      case '/quit':
        await _quitApp();
      default:
        _pushSystemMessage('未知命令:$command。输入 /help 查看命令。');
    }
  }

  /// 退出前收尾：流式进行中先停止并等待 run 完全落库（最多 3s），
  /// 避免退出时留下未 finalize 的空占位消息、丢失已生成内容与
  /// [Cancelled] 标记。
  Future<void> _quitApp() async {
    if (_controller.isStreaming.value) {
      _controller.stopGenerating();
      try {
        await _controller.bridge.settled?.timeout(const Duration(seconds: 3));
      } catch (_) {
        // 超时/异常不阻塞退出
      }
    }
    shutdownApp();
  }

  // ─── 全局按键 ────────────────────────────────────────────

  bool _handleGlobalKey(KeyboardEvent event) {
    // 审批模态优先:输入被屏蔽,按键只服务审批
    final permission = _permissionRequest;
    if (permission != null) {
      switch (event.logicalKey) {
        case LogicalKey.keyY:
          _resolvePermission(true, false);
          return true;
        case LogicalKey.keyN:
          _resolvePermission(false, false);
          return true;
        case LogicalKey.keyA:
          _resolvePermission(true, true);
          return true;
        case LogicalKey.escape:
          // Esc = 拒绝 + 停止生成。直接关闭审批条(不依赖 cancelToken:
          // 无活动 run 时 currentCancelToken 为 null,依赖它审批会悬挂)
          _controller.stopGenerating();
          _resolvePermission(false, false);
          return true;
      }
      return true; // 模态期间吞掉所有按键,防止误操作
    }
    final skillTrust = _skillTrustRequest;
    if (skillTrust != null) {
      switch (event.logicalKey) {
        case LogicalKey.keyY:
          skillTrust.completer.complete(true);
          _skillTrustRequest = null;
          setState(() {});
          return true;
        case LogicalKey.keyN:
          skillTrust.completer.complete(false);
          _skillTrustRequest = null;
          setState(() {});
          return true;
        case LogicalKey.escape:
          skillTrust.completer.complete(false);
          _skillTrustRequest = null;
          setState(() {});
          return true;
      }
      return true;
    }

    // 选择模态
    if (_picker != null) {
      return _handlePickerKey(event);
    }

    // 停止生成
    if (event.logicalKey == LogicalKey.escape &&
        _controller.isStreaming.value) {
      _controller.stopGenerating();
      return true;
    }

    // Ctrl 组合快捷键
    if (event.modifiers.ctrl) {
      switch (event.logicalKey) {
        case LogicalKey.keyN:
          if (_streamingGuard()) return true;
          unawaited(_controller.newChat());
          return true;
        case LogicalKey.keyP:
          if (_streamingGuard()) return true;
          unawaited(_switchChat(-1));
          return true;
        case LogicalKey.keyM:
          unawaited(_pickModel());
          return true;
        case LogicalKey.keyS:
          unawaited(_pickSentinel());
          return true;
      }
    }
    return false;
  }

  // ─── 权限审批(M3) ────────────────────────────────────────

  Future<PermissionDecision> _handlePermission(
    String toolName,
    String arguments,
  ) async {
    final completer = Completer<PermissionDecision>();
    _permissionRequest = _PermissionRequest(toolName, arguments, completer);
    setState(() {});

    // 用户取消 run 时自动拒绝并关闭审批条。
    // 身份检查:取消回调只清理"自己的"请求——若旧请求未决期间
    // 新权限请求已到达,无条件置 null 会清掉新请求的显示,
    // 其 completer 将永远挂起(Agent 卡死)。mounted 检查:
    // app 退出瞬间取消回调触发时避免 dispose 后 setState。
    final cancelToken = component.di.agentService.currentCancelToken;
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancelled.then((_) {
          if (!mounted) return;
          if (!completer.isCompleted) {
            completer.complete(const PermissionDecision(approved: false));
            if (identical(_permissionRequest?.completer, completer)) {
              _permissionRequest = null;
            }
            setState(() {});
          }
        }),
      );
    }
    return completer.future;
  }

  /// picker 按键处理(全局键与输入区共用,模态期间拦截方向键)。
  bool _handlePickerKey(KeyboardEvent event) {
    final picker = _picker;
    if (picker == null) return false;
    switch (event.logicalKey) {
      case LogicalKey.arrowUp:
        picker.index =
            (picker.index - 1 + picker.labels.length) % picker.labels.length;
        setState(() {});
        return true;
      case LogicalKey.arrowDown:
        picker.index = (picker.index + 1) % picker.labels.length;
        setState(() {});
        return true;
      case LogicalKey.enter:
        _closePicker(picker.index);
        return true;
      case LogicalKey.escape:
        _closePicker(null);
        return true;
    }
    return true; // 模态期间吞掉其他按键,防止误操作
  }

  Future<bool> _handleSkillTrust(String dir, List<String> names) async {
    final completer = Completer<bool>();
    _skillTrustRequest = _SkillTrustRequest(dir, names, completer);
    setState(() {});
    return completer.future;
  }

  /// /providers:选择 provider 后进入 API key 输入模式。
  Future<void> _manageProviders() async {
    final providers = await _controller.availableProviders;
    if (providers.isEmpty) {
      _pushSystemMessage('暂无 provider。');
      return;
    }
    final picked = await _openPicker(
      title: '选择 Provider(配置 API key)',
      labels: [
        for (final p in providers)
          '${p.name} — ${p.apiKey.isEmpty ? '未配置 key' : '已配置 key'}',
      ],
      initialIndex: 0,
    );
    if (picked == null || picked >= providers.length) return;
    setState(() => _keyInputProvider = providers[picked]);
    _pushSystemMessage('为 ${providers[picked].name} 输入 API key(回车保存,留空取消)。');
  }

  /// 输入变化时实时计算斜杠命令建议:文本以 `/` 开头时按命令前缀过滤
  /// (取第一个空格前的命令部分,大小写不敏感),否则清空。
  void _onInputChanged() {
    final text = _textController.text;
    List<(String, String)> suggestions = const [];
    if (text.startsWith('/')) {
      final spaceIndex = text.indexOf(' ');
      final head = spaceIndex >= 0 ? text.substring(0, spaceIndex) : text;
      final needle = head.toLowerCase();
      suggestions = [
        for (final command in _allCommands)
          if (command.$1.toLowerCase().startsWith(needle)) command,
      ];
    }
    if (!_sameSuggestions(suggestions, _commandSuggestions)) {
      _commandSuggestions = suggestions;
      setState(() {});
      // 建议栏消失导致内容收缩:若滚动位置超出新高度,回到底部。
      // (如输入 /help 提交后建议栏让出空间,offset 仍停在旧位置,
      // 帮助文本顶部会被裁掉)
      if (suggestions.isEmpty && mounted) {
        final binding = NoctermBinding.instance;
        if (binding is SchedulerBinding) {
          binding.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scrollController.offset > _scrollController.maxScrollExtent) {
              _scrollController.jumpTo(_scrollController.maxScrollExtent);
            }
          });
        }
      }
    }
  }

  void _onMessagesChanged() {
    _refresh();
    // 自动滚底:仅当用户停留在底部时跟随(向上翻阅历史不打扰)。
    // 必须在帧渲染后(新内容的 maxScrollExtent 已更新)再跳,
    // setState 刚标记 dirty 时 maxScrollExtent 还是旧值。
    if (_stickToBottom) {
      final binding = NoctermBinding.instance;
      if (binding is SchedulerBinding) {
        binding.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollController.jumpTo(_scrollController.maxScrollExtent);
        });
      }
    }
  }

  void _onScrollChanged() {
    _stickToBottom = _scrollController.atEnd;
  }

  // ─── 选择模态(常驻组件,visible 切换;不用 Overlay ─────────
  // 避免 NoctermApp/Navigator 对根树的挂载时序依赖) ─────────

  Future<int?> _openPicker({
    required String title,
    required List<String> labels,
    required int initialIndex,
  }) async {
    final completer = Completer<int?>();
    _picker = _PickerState(
      title: title,
      labels: labels,
      index: initialIndex.clamp(0, labels.length - 1),
      completer: completer,
    );
    setState(() {});
    return completer.future;
  }

  Future<void> _pickModel() async {
    final models = await _controller.availableModelsWithProvider;
    if (models.isEmpty) {
      _pushSystemMessage('暂无模型。请先在 provider 配置 API key。');
      return;
    }
    final current = _controller.currentModel.value;
    final initial = models.indexWhere((m) => m.$1.id == current?.id);
    final picked = await _openPicker(
      title: '选择模型',
      labels: [
        // 模型名 (提供商名):模型 id 是发给提供商 API 的实际模型,
        // 展示提供商帮助区分同名模型来自哪家
        for (final (model, providerName) in models)
          '${model.name} ($providerName)',
      ],
      initialIndex: initial < 0 ? 0 : initial,
    );
    if (picked != null && picked < models.length) {
      await _controller.switchModel(models[picked].$1);
    }
  }

  Future<void> _pickSentinel() async {
    final sentinels = await _controller.availableSentinels;
    if (sentinels.isEmpty) {
      _pushSystemMessage('暂无角色。');
      return;
    }
    final current = _controller.currentSentinel.value;
    final initial = sentinels.indexWhere((s) => s.id == current?.id);
    final picked = await _openPicker(
      title: '选择角色',
      labels: [for (final s in sentinels) '${s.name} — ${s.description}'],
      initialIndex: initial < 0 ? 0 : initial,
    );
    if (picked != null && picked < sentinels.length) {
      await _controller.switchSentinel(sentinels[picked]);
    }
  }

  void _pushSystemMessage(String content) {
    if (content.isEmpty) return;
    final message = MessageEntity(
      chatId: _controller.currentChat.value?.id ?? -1,
      role: 'system',
      content: content,
    );
    // 仅内存展示,不落库(切换聊天后消失)
    _controller.pushTransientMessage(message);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _resolvePermission(bool approved, bool persistExact) {
    final request = _permissionRequest;
    if (request == null) return;
    request.completer.complete(
      PermissionDecision(approved: approved, persistExact: persistExact),
    );
    _permissionRequest = null;
    setState(() {});
  }

  Future<void> _saveApiKey(ProviderEntity provider, String apiKey) async {
    await _controller.updateProviderApiKey(provider, apiKey);
    _pushSystemMessage('已保存 ${provider.name} 的 API key。现在可以发送消息了。');
  }

  /// 流式期间的切换守卫:提示用户并返回 true(调用方直接返回)。
  bool _streamingGuard() {
    if (_controller.isStreaming.value) {
      _pushSystemMessage('正在生成中,请等待完成或按 Esc 停止。');
      return true;
    }
    return false;
  }

  // ─── 发送与命令 ──────────────────────────────────────────

  void _submit(String text) {
    // API key 输入模式:回车提交 key(留空视为取消)。
    // 该分支必须在空文本检查之前:留空回车是合法的"取消"操作。
    final keyProvider = _keyInputProvider;
    if (keyProvider != null) {
      _keyInputProvider = null;
      _textController.clear();
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        _pushSystemMessage('已取消配置 ${keyProvider.name} 的 API key。');
      } else {
        unawaited(_saveApiKey(keyProvider, trimmed));
      }
      setState(() {});
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    // 唯一匹配的快捷执行:必须在 clear **之前**捕获建议——
    // clear 会同步触发 _onInputChanged 清空 _commandSuggestions。
    final singleCommand =
        trimmed.startsWith('/') && _commandSuggestions.length == 1
        ? _commandSuggestions.first.$1
        : null;
    _textController.clear();

    if (_controller.isStreaming.value) {
      // 输入框已 clear,给出可见反馈避免"消息凭空消失"
      _pushSystemMessage('正在生成中,请等待完成或按 Esc 停止。');
      return;
    }

    if (trimmed.startsWith('/')) {
      // 建议唯一匹配时,回车直接执行匹配的命令(补全命令部分、
      // 保留已输入参数)。如输入 /m 回车 → 执行 /model;
      // /j xxx 回车 → 执行 /json xxx。多匹配或无匹配走常规命令处理。
      if (singleCommand != null) {
        final spaceIndex = trimmed.indexOf(' ');
        final rest = spaceIndex >= 0 ? trimmed.substring(spaceIndex) : '';
        unawaited(_handleCommand(singleCommand + rest));
        return;
      }
      unawaited(_handleCommand(trimmed));
    } else {
      unawaited(_controller.sendMessage(trimmed));
    }
  }

  Future<void> _switchChat(int offset) async {
    final chats = _controller.chatList.value;
    if (chats.length < 2) return;
    final currentId = _controller.currentChat.value?.id;
    final index = chats.indexWhere((h) => h.chat.id == currentId);
    if (index < 0) return;
    final next = chats[(index + offset + chats.length) % chats.length];
    await _controller.selectChat(next.chat);
  }

  Future<void> _switchChatPicker() async {
    final chats = _controller.chatList.value;
    if (chats.isEmpty) return;
    final currentId = _controller.currentChat.value?.id;
    final initial = chats.indexWhere((h) => h.chat.id == currentId);
    final picked = await _openPicker(
      title: '选择聊天',
      labels: [
        for (final h in chats)
          '#${h.chat.id} ${h.chat.title} — '
              '${truncateText(sanitizeAnsi(h.lastMessageContent), 24)}',
      ],
      initialIndex: initial < 0 ? 0 : initial,
    );
    if (picked != null && picked < chats.length) {
      await _controller.selectChat(chats[picked].chat);
    }
  }

  static bool _sameSuggestions(
    List<(String, String)> a,
    List<(String, String)> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _PermissionRequest {
  final String toolName;
  final String arguments;
  final Completer<PermissionDecision> completer;
  _PermissionRequest(this.toolName, this.arguments, this.completer);
}

class _PickerState {
  final String title;
  final List<String> labels;
  final Completer<int?> completer;
  int index;
  _PickerState({
    required this.title,
    required this.labels,
    required this.index,
    required this.completer,
  });
}

class _SkillTrustRequest {
  final String dir;
  final List<String> names;
  final Completer<bool> completer;
  _SkillTrustRequest(this.dir, this.names, this.completer);
}
