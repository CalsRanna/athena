import 'package:athena_core/coordinator/streaming_message_buffer.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_gui/extension/list_signal_extension.dart';
import 'package:signals/signals.dart';

/// 当前显示的消息窗口：分页、流式合并、加载代次。
///
/// 从 `ChatViewModel` 整块切出来。它自有一套状态（窗口列表、最旧一条的 seq、两个
/// 加载代次、流式合并缓冲）和一套完整的并发语义，与列表 CRUD、参数、run 交互都
/// 不相干，但它自己要管住三件容易互相踩踏的事：
///
/// - **代次**（[generation]）回答「这次异步加载还属于当前这次选择吗」。切会话、
///   新建草稿、刷新都会推进它，加载回来对不上就整批丢弃——否则会把 A 的消息写进 B；
/// - **分页**只保留最近一页；向顶部翻页时把更早的一页接在前面。最旧一条的 seq 是
///   翻页游标，为空（或翻到文件头）就表示没有更早的了；
/// - **流式合并**：读列表之前要先冲刷挂起增量，否则读到的是过期列表；而翻页
///   prepend 之前也必须冲刷——缓冲里那批待提交的增量攥着一份完整快照，直接整表
///   替换会把它们挤掉。
class MessageWindowStore {
  MessageWindowStore({
    required MessageRepository repository,
    required String? Function() currentChatId,
    this.pageSize = 50,
    this.flushInterval = StreamingMessageBuffer.defaultInterval,
  }) : _repository = repository,
       _currentChatId = currentChatId;

  final MessageRepository _repository;
  final String? Function() _currentChatId;

  /// 一页的条数。
  final int pageSize;

  final Duration flushInterval;

  /// 当前窗口，按 seq 升序。
  final messages = listSignal<MessageEntity>([]);

  /// 流式增量合并（策略本身在 core 的 [StreamingMessageBuffer] 里）。
  late final StreamingMessageBuffer _buffer = StreamingMessageBuffer(
    interval: flushInterval,
    snapshot: () => messages.value,
    commit: (pending) => messages.value = pending,
  );

  int? _oldestSeq;
  bool _loadingOlder = false;
  int _generation = 0;
  int _olderGeneration = 0;

  /// 还有更早的消息没读进来。
  bool get hasOlder => _oldestSeq != null;

  /// 当前加载代次；配合 [isCurrent] 使用。
  int get generation => _generation;

  /// 开始一次新的加载：推进代次、重置分页、丢弃挂起增量，并返回新代次。
  ///
  /// 丢弃挂起增量是必须的——那批增量属于上一个窗口，留着会在下一次提交时把旧
  /// 消息写回来。
  int beginLoad() {
    _generation++;
    _resetPagination();
    _buffer.discard();
    return _generation;
  }

  /// 这次加载是否仍然有效：代次没变、且当前对话仍是 [chatId]。
  bool isCurrent(int generation, String chatId) =>
      generation == _generation && _currentChatId() == chatId;

  /// 首屏：会话小到能一次读进来时给整段（此后 [hasOlder] 为假），否则只给最新一页。
  Future<MessageWindow> loadInitial(String chatId) => _loadPage(chatId);

  /// 把一页结果铺成当前窗口（整表替换）。
  void applyPage(MessageWindow page) {
    _buffer.discard();
    messages.value = page.messages;
    _oldestSeq = page.hasOlder && page.messages.isNotEmpty
        ? page.messages.first.seq
        : null;
  }

  /// 直接清空窗口（切会话/新建草稿时先卸下旧列表）。
  void clear() {
    messages.value = [];
  }

  /// 向列表顶部追加一页更早的消息，返回实际新增条数。
  Future<int> loadOlder() async {
    final chatId = _currentChatId();
    final beforeSeq = _oldestSeq;
    if (_loadingOlder || chatId == null || beforeSeq == null) return 0;

    _loadingOlder = true;
    final selectionGeneration = _generation;
    final loadGeneration = ++_olderGeneration;
    try {
      final page = await _loadPage(chatId, beforeSeq: beforeSeq);
      if (selectionGeneration != _generation ||
          loadGeneration != _olderGeneration ||
          _currentChatId() != chatId) {
        return 0;
      }

      // 分页 IO 期间可能收到了流式增量，合并旧消息前先把增量冲刷到当前列表。
      _buffer.flush();
      if (page.messages.isEmpty) {
        _oldestSeq = null;
        return 0;
      }

      messages.value = [...page.messages, ...messages.value];
      _oldestSeq = page.hasOlder ? page.messages.first.seq : null;
      return page.messages.length;
    } finally {
      if (loadGeneration == _olderGeneration) {
        _loadingOlder = false;
      }
    }
  }

  /// 重新读一遍当前对话的窗口（删消息后用）。
  Future<void> refresh(String chatId) async {
    if (_currentChatId() != chatId) return;
    final generation = beginLoad();
    final page = await _loadPage(chatId);
    if (!isCurrent(generation, chatId)) return;
    applyPage(page);
  }

  // ─── 流式增量 ───────────────────────────────────────────────

  /// 把一条增量交给合并缓冲（同 id 替换、否则追加），到窗口末统一提交。
  void addBuffered(MessageEntity message, String chatId) {
    _buffer.add(message, scope: chatId);
  }

  /// 立即提交挂起增量。收尾、以及任何需要读到最新列表的操作之前必须调用，
  /// 否则会读到过期的 [messages]。
  void flush() => _buffer.flush();

  /// 只冲刷属于 [chatId] 的挂起增量——无条件冲刷会把别的对话的缓冲也提交掉。
  void flushFor(String chatId) {
    if (_buffer.hasPendingFor(chatId)) _buffer.flush();
  }

  /// 丢弃挂起增量。整表即将被替换（切会话、新建草稿）时使用。
  void discardPending() => _buffer.discard();

  /// 立即追加或替换一条消息（不走缓冲）。
  ///
  /// 用于切换对话的竞态下合并内存快照：占位消息可能已在列表里（快照合并或 DB
  /// 预读），按 id 替换避免重复追加。
  void appendOrReplaceNow(MessageEntity message) {
    if (!messages.replaceWhere((m) => m.id == message.id, message)) {
      messages.value = [...messages.value, message];
    }
  }

  // ─── 内部 ──────────────────────────────────────────────────

  void _resetPagination() {
    _oldestSeq = null;
    _loadingOlder = false;
    _olderGeneration++;
  }

  Future<List<MessageEntity>> _loadRecent(
    String chatId, {
    required int count,
    int? beforeSeq,
  }) async {
    final repository = _repository;
    if (repository is RecentMessageRepository) {
      return (repository as RecentMessageRepository).loadRecentMessages(
        chatId,
        count: count,
        beforeSeq: beforeSeq,
      );
    }

    final all = await repository.getMessagesByChatId(chatId);
    final eligible = beforeSeq == null
        ? all
        : all.where((message) => message.seq < beforeSeq).toList();
    if (eligible.length <= count) return eligible;
    return eligible.sublist(eligible.length - count);
  }

  Future<MessageWindow> _loadPage(String chatId, {int? beforeSeq}) async {
    final repository = _repository;
    if (beforeSeq == null && repository is RecentMessageRepository) {
      // 首屏：够小的会话整段给（此后 hasOlder=false，不再翻页），超过阈值的
      // 仍只给尾部一页。轮次条 hover/点击、列表高度因此不再分两段。
      return (repository as RecentMessageRepository).loadInitialMessages(
        chatId,
        pageSize: pageSize,
      );
    }
    final loaded = await _loadRecent(
      chatId,
      count: pageSize + 1,
      beforeSeq: beforeSeq,
    );
    final hasOlder = loaded.length > pageSize;
    final page = hasOlder ? loaded.sublist(loaded.length - pageSize) : loaded;
    return (hasOlder: hasOlder, messages: page);
  }
}
