import 'dart:async';

import 'package:athena_core/entity/message_entity.dart';

/// 把流式期间的高频消息更新合并成「每个窗口提交一次」。
///
/// 为什么必须合并：LLM 每个 token 触发一次消息更新，直写前端状态会让每个 delta
/// 都做一遍整表复制 + 全列表重建 + 正文全量重解析。消息数 M、输出 N token 时是
/// O(N·M) 次复制与 O(N²) 量级的解析。合并后提交频率与 token 速率解耦——600 tok/s
/// 也恒定 10 次/秒。
///
/// 这段逻辑两个前端各写过一遍（GUI 的 `ChatViewModel`、TUI 的 `ChatController`），
/// 靠注释互指保持同步，而且实际已经漂移：TUI 的定时器路径提交前裁窗口，收尾路径
/// 不裁。合并策略是引擎侧的事实，所以收在 core；「取哪份当前列表起算」由
/// [snapshot] 决定，「提交到哪里」由 [commit] 决定——GUI 写信号、TUI 写裁过窗口的
/// 信号，那是前端的选择。
class StreamingMessageBuffer {
  StreamingMessageBuffer({
    required List<MessageEntity> Function() snapshot,
    required void Function(List<MessageEntity> messages) commit,
    this.interval = defaultInterval,
  }) : _snapshot = snapshot,
       _commit = commit;

  /// 合并窗口。
  ///
  /// 100ms 与 token 速率无关，取决于一次提交的成本：全树 build + 流式长文本
  /// layout + 正文全量重解析。10fps 的文本刷新在视觉上已经连续，再快只是徒增
  /// CPU。
  static const defaultInterval = Duration(milliseconds: 100);

  final Duration interval;
  final List<MessageEntity> Function() _snapshot;
  final void Function(List<MessageEntity> messages) _commit;

  /// 待提交列表；null = 无挂起增量。
  List<MessageEntity>? _pending;

  /// [_pending] 的归属。切到别的 scope 后残留缓冲不得写进新列表。
  String? _scope;

  Timer? _timer;

  /// 是否有属于 [scope] 的挂起增量。调用方据此决定「要不要在这里刷新」——
  /// 无条件刷新会把别的对话的缓冲也提交掉。
  bool hasPendingFor(String? scope) => _pending != null && _scope == scope;

  /// 追加或按 id 替换一条消息，并安排一次窗口末的提交。
  ///
  /// 追加与更新共用同一个列表，是为了保证「先追加占位、再更新内容」的顺序不被
  /// 打乱——顺序一旦反转，按 id 的替换找不到目标，增量会被静默丢弃。
  void add(MessageEntity message, {String? scope}) {
    final pending = _pendingFor(scope);
    // 流式增量几乎总命中最后一条：先看尾部，省掉每个事件一次 O(消息数) 的扫描
    //（高 token 速率下这是每秒上千次）。
    if (pending.isNotEmpty && pending.last.id == message.id) {
      pending[pending.length - 1] = message;
    } else {
      final index = pending.indexWhere((m) => m.id == message.id);
      if (index >= 0) {
        pending[index] = message;
      } else {
        pending.add(message);
      }
    }
    _schedule();
  }

  /// 立即把挂起增量交给 [commit]（同步）。收尾、以及任何需要读到最新列表的
  /// 用户操作之前必须调用，否则会读到过期的列表。
  ///
  /// 无挂起增量时是 no-op，不会重复提交。
  void flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _scope = null;
    _commit(pending);
  }

  /// 丢弃挂起增量且不提交。
  ///
  /// 整表即将被替换（切换对话、新建草稿、释放）时使用：冲刷旧缓冲会把上一个
  /// 对话的消息写进新列表。
  void discard() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _scope = null;
  }

  /// 首次从当前列表复制一份，之后原地变异——省掉每个事件一次的整表复制。
  ///
  /// scope 变了就重新取快照：旧对话的 pending 不能成为新对话列表的基础。
  List<MessageEntity> _pendingFor(String? scope) {
    if (_pending == null || _scope != scope) {
      _pending = List<MessageEntity>.of(_snapshot());
      _scope = scope;
    }
    return _pending!;
  }

  void _schedule() {
    _timer ??= Timer(interval, () {
      _timer = null;
      flush();
    });
  }
}
