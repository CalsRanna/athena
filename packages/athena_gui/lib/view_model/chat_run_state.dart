import 'dart:async';

import 'package:athena_core/entity/token_usage.dart';
import 'package:signals/signals.dart';

/// 运行态：哪些对话在跑、当前迭代/工具/用量、以及自动汇报的记账。
///
/// 从 `ChatViewModel` 切出来。它不含「什么时候做」——那是 ViewModel 的事（它才是
/// 驱动器）；这里只回答「现在是什么状态」以及几个必须成套做的增删。抽出来的理由
/// 是这些增删原先散在约二十处，同样的三条规则被反复手写：
///
/// - **运行指示按会话记账**：加之前先判存在，去掉时按 id 过滤，重复加会出现两条；
/// - **实时进度只属于当前显示的对话**：切走之后到达的迭代/工具/用量事件不该写到
///   别的对话上，所以清理时都要对一次 chatId；
/// - **收尾不认事件只认登记**：用户发起的 run 以自己的 settled 为准，且要防止迟到
///   的收尾把下一轮的状态抹掉（见 [unregisterRun] 的同一性判断）。
class ChatRunState {
  /// 正在运行的会话 id。侧栏与发送键据此显示运行指示。
  final streamingChatIds = listSignal<String>([]);

  final currentIteration = signal(0);
  final currentToolName = signal<String?>(null);
  final currentTokenUsage = signal<TokenUsage?>(null);

  /// chatId → 用户发起的那次 sendMessage 的收尾。新输入要等它落库完成再启动，
  /// 免得迟到的事件覆盖新一轮。
  final Map<String, Completer<void>> _settledByChat = {};

  /// 已经点亮运行指示的自动汇报会话（汇报 run 没有 sendMessage 的收尾流程）。
  final Set<String> _reporting = {};

  bool isStreaming(String chatId) => streamingChatIds.value.contains(chatId);

  /// 点亮运行指示；已在其中时不动（重复加会出现两条）。
  void beginStreaming(String chatId) {
    if (isStreaming(chatId)) return;
    streamingChatIds.value = [...streamingChatIds.value, chatId];
  }

  void endStreaming(String chatId) {
    streamingChatIds.value = streamingChatIds.value
        .where((id) => id != chatId)
        .toList();
  }

  /// 实时进度只写给当前对话看的那些信号。
  void noteIteration(int iteration) => currentIteration.value = iteration;

  void noteTool(String? toolName) => currentToolName.value = toolName;

  void noteUsage(TokenUsage? usage) => currentTokenUsage.value = usage;

  /// 清掉「正在跑第几轮 / 正在用哪个工具」。只在当前显示的对话就是 [chatId]
  /// 时清——别的对话的进度条不该被这条的收尾抹掉。
  void clearLiveProgressFor(String chatId, {required String? currentChatId}) {
    if (currentChatId != chatId) return;
    currentIteration.value = 0;
    currentToolName.value = null;
  }

  /// 登记一次用户发起的 run。
  Completer<void> registerRun(String chatId) {
    final settled = Completer<void>();
    _settledByChat[chatId] = settled;
    return settled;
  }

  bool hasRun(String chatId) => _settledByChat.containsKey(chatId);

  Future<void>? settledOf(String chatId) => _settledByChat[chatId]?.future;

  Iterable<String> get registeredChatIds => _settledByChat.keys;

  /// 注销登记。只在登记的还是这一次时移除——否则会把新的一轮抹掉。
  void unregisterRun(String chatId, Completer<void> settled) {
    if (identical(_settledByChat[chatId], settled)) {
      _settledByChat.remove(chatId);
    }
  }

  bool isReporting(String chatId) => _reporting.contains(chatId);

  /// 记下这条对话的自动汇报已经点亮过指示。
  void markReporting(String chatId) => _reporting.add(chatId);

  /// 汇报收尾：返回它原本是否在记账中（重复收尾返回 false）。
  bool takeReportFinished(String chatId) => _reporting.remove(chatId);

  /// 所有可能还在跑的会话：点亮了指示的，加上登记了收尾的。
  ///
  /// 重置数据前要把它们全部停掉并等收尾——run 若在会话文件删掉之后继续写，会重建出
  /// 没有会话头的文件。汇报会话本来就在 [streamingChatIds] 里，不必另算。
  Set<String> get runningChatIds => {
    ...streamingChatIds.value,
    ..._settledByChat.keys,
  };
}
