import 'package:athena_core/agent/cancel_token.dart';

/// 一个选项：标签 + 一句话说明。
///
/// 选项由模型生成、宿主渲染，形状与 Claude Code 的 AskUserQuestion 对齐
/// （每问 2-4 个选项）。`preview` 一类需要宿主额外开启的字段不在此列——
/// 没有渲染方支持时生成它只会白烧 token。
class ElicitOption {
  const ElicitOption({required this.label, required this.description});

  final String label;
  final String description;

  Map<String, dynamic> toJson() => {'label': label, 'description': description};
}

/// 一个问题：完整问句 + 短标签 + 选项 + 是否多选。
class ElicitQuestion {
  const ElicitQuestion({
    required this.question,
    required this.header,
    required this.options,
    this.multiSelect = false,
  });

  final String question;

  /// 短标签（≤12 字符），供宿主在窄卡片/终端行内显示。
  final String header;

  final List<ElicitOption> options;
  final bool multiSelect;

  Map<String, dynamic> toJson() => {
    'question': question,
    'header': header,
    'options': options.map((o) => o.toJson()).toList(),
    'multiSelect': multiSelect,
  };
}

/// 提问回调：由各 App 注入（GUI=会话内提问卡片，TUI=终端提示）。
///
/// 返回「问题文本 → 用户所选 label」；多选按 `", "` 连接，
/// 用户自行输入的文本原样作为值。`null` 或空 map 表示用户未作答。
///
/// [cancelToken] 供调用方在 run 取消时立即收起提问卡片。
typedef ElicitPrompt =
    Future<Map<String, String>?> Function(
      int chatId,
      List<ElicitQuestion> questions,
      CancelToken cancelToken,
    );

/// 提问通道：引擎在每次 run 开始时绑定，随 run 结束失效。
///
/// 与审批通道的分工：审批问的是「要不要做」（宿主已有
/// `PermissionPrompt`，二值 + 落规则）；这里问的是「你要哪个」，
/// 需要携带选项与答案，两者不可混用。
class ElicitChannel {
  ElicitChannel({
    required this.chatId,
    required this.prompt,
    required this.cancelToken,
  });

  final int chatId;

  /// null = 本会话没有提问 UI（移动端 / 未注入 onElicit / headless）。
  final ElicitPrompt? prompt;

  final CancelToken cancelToken;

  /// 本会话是否真的能问到人。false 时工具应降级而非等待。
  bool get available => prompt != null;

  /// 提问并等待作答。
  ///
  /// 无提问 UI 或 run 被取消时返回 null——与权限门同一写法
  /// （`Future.any` 让取消与作答竞速），保证等待**绝不**挂死：
  /// 官方 Claude Code SDK 承认其回调可无限挂起、需另用 PreToolUse 的
  /// defer 规避，这里用取消信号把这个问题在架构上消掉。
  Future<Map<String, String>?> ask(List<ElicitQuestion> questions) async {
    final prompt = this.prompt;
    if (prompt == null) return null;
    return Future.any<Map<String, String>?>([
      prompt(chatId, questions, cancelToken),
      cancelToken.whenCancelled.then<Map<String, String>?>((_) => null),
    ]);
  }
}

/// 需要提问通道的工具实现此接口：引擎在 run 内提供 [ElicitChannel]。
///
/// 工具集是长生命周期单例，而通道随 run 绑定（含 chatId 与取消信号），
/// 因此按调用传入而非构造注入——同 `CancellableTool` 处理取消信号的方式。
/// 这样多个 run 并发时各自持有自己的通道，不会互相串台。
abstract interface class ElicitChannelAware {
  Future<String> executeWithElicit(
    Map<String, dynamic> args, {
    required ElicitChannel channel,
    void Function(String partialResult)? onUpdate,
  });
}
