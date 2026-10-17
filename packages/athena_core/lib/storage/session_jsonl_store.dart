import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/conversation_summary.dart';
import 'package:athena_core/entity/rewind_result.dart';
import 'package:athena_core/storage/id_generator.dart';
import 'package:athena_core/storage/serial_lock.dart';
import 'package:athena_core/util/atomic_file_write.dart';
import 'package:athena_core/util/logger_util.dart';

/// 单会话文件存储:`sessions/{chatId}.jsonl`。
///
/// 一个对话一个文件,首行是会话元数据,后续行是消息,行序即消息序:
/// ```jsonl
/// {"type":"chat","id":"chat-uuid","title":"...","model_id":"model-uuid",...}
/// {"type":"message","id":"message-uuid-1","seq":1,"chat_id":"chat-uuid","role":"user","content":"..."}
/// {"type":"message","id":"message-uuid-2","seq":2,"chat_id":"chat-uuid","role":"assistant","content":"..."}
/// ```
///
/// 设计要点:
/// - **单写者锁**:所有修改在单次锁内完成(读-改-写原子),流式期间
///   的 update(整文件重写)与 append 并发时不丢行(锁是实例字段,调用方
///   必须按文件缓存共享实例,锁才能跨调用生效)
/// - **跨进程文件锁**:GUI 与 TUI 共享目录,修改再套一层跨进程排它锁
///   (`<root>/.locks/` 下,见 [LockRegistry]),另一进程的重写(rename 换
///   inode)不会吞掉本进程的 append
/// - **原子写**:整文件重写走临时文件 + rename;读不加锁,读到的要么是
///   旧文件要么是新文件
/// - **损坏容错**:损坏行(含非法 UTF-8)跳过并记日志,chat 记录缺失时按无会话
///   处理;追加前补齐上一行缺失的换行,写一半的行不会吞掉下一条消息
/// - 行更新采用整文件重写:会话数据规模有限,重写简单可靠
class SessionJsonlStore {
  SessionJsonlStore({
    required this.file,
    required LockRegistry locks,
    this.idGenerator = const IdGenerator(),
  }) : _locks = locks;

  final File file;

  /// 锁放哪由它决定,见 [LockRegistry]。
  final LockRegistry _locks;

  final IdGenerator idGenerator;

  Future<void>? _lock;

  static const chatType = 'chat';
  static const messageType = 'message';

  /// 每个会话保留的回退快照上限。快照是整会话副本，长期不清理会让磁盘
  /// 占用随回退次数线性增长；超出后只保留最新的若干份。
  static const int maxRewindSnapshots = 10;

  /// 进程内串行(读写都排队,读不会夹在本进程写的中间)。
  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_lock, action, (f) => _lock = f);
  }

  /// 修改:进程内串行 + 跨进程文件锁。
  Future<T> _mutate<T>(Future<T> Function() action) {
    return _serialized(() => withFileLock(_locks.forTarget(file), action));
  }

  // ─────────────────────────── 会话元数据(首行) ───────────────────────────

  /// 读取会话元数据;文件缺失/损坏时返回 null。
  ///
  /// **快速路径只读首行。** 元数据行由 [writeChatRow] 的 `insert(0)` 保证在
  /// 文件头，而整文件解码在大会话上很贵（48MB 实测约 120ms）；`getChatById`
  /// 在每次 usage 事件后都会被调用一次（见 `agent_run_coordinator` 的
  /// `AgentUsageEvent` 分支），这个读放大直接叠在工具循环的关键路径上。
  /// 首行不是元数据行（历史布局）或首行超长/损坏时回退整文件扫描，
  /// 「跳过损坏行」的既有语义不变。
  Future<Map<String, dynamic>?> readChatRow() {
    return _serialized(() async {
      final first = await _readFirstRow();
      if (first != null && first['type'] == chatType) return first;
      final rows = await _readAllRows();
      for (final row in rows) {
        if (row['type'] == chatType) return row;
      }
      return null;
    });
  }

  /// 只读文件第一行并解析;空文件、首行超长（无换行）或首行损坏时返回 null。
  Future<Map<String, dynamic>?> _readFirstRow() async {
    if (!await file.exists()) return null;
    final raf = await file.open();
    try {
      final length = await raf.length();
      if (length == 0) return null;
      final probe = await raf.read(math.min(_chatRowProbeBytes, length));
      final newline = probe.indexOf(0x0A);
      // 没读到换行 = 首行超出探测窗口（或读失败）：不在这里猜，交给整文件路径
      if (newline < 0) return null;
      return _decodeLineBytes(Uint8List.sublistView(probe, 0, newline));
    } finally {
      await raf.close();
    }
  }

  /// 首行探测窗口。元数据行是几十个键的扁平 JSON，1KB 上下；64KB 给足了
  /// 余量，又远小于任何需要整文件扫描的阈值。
  static const int _chatRowProbeBytes = 64 * 1024;

  /// 替换首行的会话元数据;不存在则插入到文件头。
  Future<void> writeChatRow(
    Map<String, dynamic> row, {
    bool createOnly = false,
  }) {
    return _mutate(() async {
      if (createOnly && await file.exists()) {
        throw StateError('Session already exists: ${file.path}');
      }
      final rows = await _readAllRows();
      row['type'] = chatType;
      final index = rows.indexWhere((r) => r['type'] == chatType);
      if (index >= 0) {
        rows[index] = row;
      } else {
        rows.insert(0, row);
      }
      await _writeAll(rows);
    });
  }

  /// 单次锁内读-改-写会话元数据(如 recordUsage 的快照写)。
  ///
  /// 文件无 chat 行时 [transform] 不执行,返回 null;成功返回更新后的行。
  /// 与独立调用的 readChatRow + writeChatRow 不同,不会被并发 updateChat
  /// 的整文件重写夹在中间丢失修改。
  ///
  /// **只重写元数据那一行**，不重编码其余消息行——理由与代价同
  /// [replaceMessage]：这里每个工具迭代都会被 `recordUsage` 调一次。
  /// 与 [replaceMessage] 的差异是元数据行**不一定是文件首行**：早期版本与
  /// [writeChatRow] 的插入路径都可能把它放在别处，所以按行扫描定位。
  Future<Map<String, dynamic>?> updateChatRow(
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) {
    return _mutate(() async {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      var lineStart = 0;
      while (lineStart < bytes.length) {
        final range = _lineRangeContaining(bytes, lineStart);
        final decoded = range.end > range.start
            ? _decodeLineBytes(
                Uint8List.sublistView(bytes, range.start, range.end),
              )
            : null;
        if (decoded != null && decoded['type'] == chatType) {
          final updated = transform(decoded);
          updated['id'] = decoded['id'];
          updated['type'] = chatType;
          await replaceFileContentBytes(
            file,
            _spliceLine(bytes, range, updated),
          );
          return updated;
        }
        if (range.after >= bytes.length) break;
        lineStart = range.after;
      }
      return null;
    });
  }

  // ─────────────────────────── 消息行 ───────────────────────────

  /// 读取全部消息行(按行序即消息序)。
  Future<List<Map<String, dynamic>>> readMessageRows() {
    return _serialized(() async {
      final rows = await _readAllRows();
      return [
        for (final row in rows)
          if (row['type'] == messageType) row,
      ];
    });
  }

  /// 顺序扫一遍文件,返回所有 user 行的 id(按行序)。
  ///
  /// 轮次指示器要的是"整段会话有多少轮"与"已加载窗口从第几轮开始",而窗口化
  /// 分页只读文件尾部若干条,只能从这里补。这是一次**整文件**扫描(长对话的
  /// JSONL 可达几百 MB),因此只做廉价的行内判定,命中 user 行才解析 JSON,
  /// 不做逐行 JSON 解码;调用方按 chatId 缓存结果,不要每次构建都调。
  Future<List<String>> loadUserMessageIds() {
    return _serialized(() async {
      if (!await file.exists()) return const [];
      final ids = <String>[];
      final lines = file
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());
      await for (final line in lines) {
        // 先按序列化后的紧凑 JSON 做判定,滤掉绝大多数 assistant 行
        if (!line.contains('"role":"user"')) continue;
        final row = _decodeRow(line);
        if (row == null ||
            row['type'] != messageType ||
            row['role'] != 'user') {
          continue;
        }
        final id = row['id'];
        if (id is String) ids.add(id);
      }
      return ids;
    });
  }

  /// 回退必须按完整文件的 seq 截断，不能使用前端分页窗口里的 id 集合。
  /// 摘要与覆盖标记一起重建，避免删除摘要后原文仍因 compacted 被过滤。
  Future<RewindResult> rewindToUserMessage(String messageId) {
    return _mutate(() async {
      final rows = await _readAllRows();
      final chatRow = rows.where((row) => row['type'] == chatType).firstOrNull;
      if (chatRow == null) throw StateError('Session does not exist.');
      final records = rows
          .where((row) => row['type'] == messageType)
          .map(MessageEntity.fromJson)
          .toList();
      final input = records.where((m) => m.id == messageId).firstOrNull;
      if (input == null || input.role != 'user') {
        throw ArgumentError('Rewind target must be an existing user message.');
      }
      var kept = records.where((m) => m.seq < input.seq).toList();
      // 旧 system 摘要没有覆盖元数据，无法证明它不含已撤回内容；直接删除
      // 又会丢掉可能仅存于摘要的早期历史，因此显式失败并保留原文件。
      if (kept.any((m) => m.role == 'system')) {
        throw UnsupportedError(
          'Cannot rewind legacy summaries without coverage metadata.',
        );
      }
      while (true) {
        final ids = kept.map((m) => m.id).toSet();
        final invalid = kept
            .where(
              (m) =>
                  ConversationSummary.isSummary(m) &&
                  (ConversationSummary.position(m) >= input.seq ||
                      !ids.containsAll(ConversationSummary.coveredIds(m))),
            )
            .toSet();
        if (invalid.isEmpty) break;
        kept = kept.where((m) => !invalid.contains(m)).toList();
      }
      final covered = <String>{
        for (final message in kept)
          if (ConversationSummary.isSummary(message))
            ...ConversationSummary.coveredIds(message),
      };
      kept = kept
          .map((m) => m.copyWith(compacted: covered.contains(m.id)))
          .toList();
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final chat = ChatEntity.fromJson(chatRow).copyWith(
        contextTokens: ChatEntity.unknownContextTokens,
        cachedTokens: ChatEntity.unknownContextTokens,
        rewoundAt: now,
        updatedAt: now,
      );
      final snapshot = '${file.path}.rewind-${idGenerator.next()}';
      // 必须先完整保留原始字节；备份失败就不提交回退。备份不以 .jsonl
      // 结尾，因此不会混入正常会话列表。
      await file.copy(snapshot);
      await _writeAll([
        {...chat.toJson(), 'type': chatType},
        for (final message in kept) {...message.toJson(), 'type': messageType},
      ]);
      // 提交成功后再淘汰旧快照；写失败时不能连带丢掉已有的恢复点。
      await _pruneRewindSnapshots(keepPath: snapshot);
      return RewindResult(
        chat: chat,
        input: input,
        snapshotPath: snapshot,
        turnStartIds: [
          for (final m in kept)
            if (m.role == 'user') m.id!,
        ],
      );
    });
  }

  /// ID 无需协调；seq 在会话写锁内按尾部递增，顺序不依赖 UUID 的时间。
  Future<Map<String, dynamic>> appendMessage(Map<String, dynamic> row) {
    return _mutate(() async {
      final last = await _loadRecentRowsUnlocked(1);
      row['id'] = idGenerator.next();
      row['seq'] = (last.isEmpty ? 0 : last.single['seq'] as int) + 1;
      row['type'] = messageType;
      await _appendRow(row);
      return row;
    });
  }

  /// 按 id 整行替换已有消息，保留原 seq；新增必须经 appendMessage。
  ///
  /// **只重编码被改的那一行，其余行按原始字节原样拼回。** 早期实现是
  /// 「全量 jsonDecode → 改一行 → 全量 jsonEncode → 整文件写」，长会话里
  /// 一次要付出整个文件的解析+编码代价，而这一步跑在调用方（GUI 的 UI
  /// isolate）上：实测 48MB 会话同步阻塞约 1.1s、3.9MB 约 116ms，而工具循环
  /// 每轮迭代都会走到这里。保留字节后同样的文件降到约 143ms / 23ms。
  ///
  /// 顺带的行为差异：全量重写会把读不出来的损坏行**丢掉**（`_readAllRows`
  /// 跳过它们），字节保留则原样留下。丢数据不是这里该做的决定，丢弃也从未
  /// 是刻意的契约。
  Future<void> replaceMessage(String id, Map<String, dynamic> row) {
    return _mutate(() async {
      if (!await file.exists()) {
        throw StateError('Message $id does not exist');
      }
      final bytes = await file.readAsBytes();
      // 定位：先按字节找 `"id":"<id>"`。id 是 UUID，jsonEncode 不转义它，
      // 所以这个标记就是它在行内的原样字节。命中位置还要解码该行确认——
      // 同一个 id 可能只是恰好出现在别行的 content 里。
      final marker = utf8.encode('"id":"$id"');
      var searchFrom = 0;
      while (true) {
        final hit = _indexOfBytes(bytes, marker, searchFrom);
        if (hit < 0) throw StateError('Message $id does not exist');
        final range = _lineRangeContaining(bytes, hit);
        final decoded = _decodeLineBytes(
          Uint8List.sublistView(bytes, range.start, range.end),
        );
        if (decoded != null &&
            decoded['type'] == messageType &&
            decoded['id'] == id) {
          row['id'] = id;
          row['type'] = messageType;
          row['seq'] = decoded['seq'];
          await replaceFileContentBytes(file, _spliceLine(bytes, range, row));
          return;
        }
        searchFrom = hit + 1;
      }
    });
  }

  /// 用 [row] 替换 [range] 对应的那一行，其余字节原样拼回。
  ///
  /// `range.after` 已跳过该行原有的换行（若有）；末行无换行时它等于行尾，
  /// 此时补上的 `\n` 正好把那行补成完整行——见 [replaceMessage] 的说明。
  static List<int> _spliceLine(
    Uint8List bytes,
    ({int start, int end, int after}) range,
    Map<String, dynamic> row,
  ) {
    return (BytesBuilder(copy: false)
          ..add(Uint8List.sublistView(bytes, 0, range.start))
          ..add(utf8.encode(jsonEncode(row)))
          ..addByte(0x0A)
          ..add(Uint8List.sublistView(bytes, range.after, bytes.length)))
        .takeBytes();
  }

  /// [offset] 所在行：`start` 与 `end` 之间是行内容（不含换行），
  /// `after` 是该行换行之后的位置（末行无换行时等于 `end`）。
  static ({int start, int end, int after}) _lineRangeContaining(
    List<int> bytes,
    int offset,
  ) {
    var start = offset;
    while (start > 0 && bytes[start - 1] != 0x0A) {
      start--;
    }
    var end = offset;
    while (end < bytes.length && bytes[end] != 0x0A) {
      end++;
    }
    return (start: start, end: end, after: end < bytes.length ? end + 1 : end);
  }

  /// 字节级子串查找（[from] 起）。逐字节比较即可：命中标记很短，
  /// 且不命中时只比对首字节就跳过。
  static int _indexOfBytes(List<int> haystack, List<int> needle, int from) {
    if (needle.isEmpty) return from <= haystack.length ? from : -1;
    final last = haystack.length - needle.length;
    for (var i = from; i <= last; i++) {
      if (haystack[i] != needle[0]) continue;
      var matched = true;
      for (var j = 1; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  /// 对命中的消息行应用 [transform],返回命中数。
  Future<int> updateMessagesWhere(
    bool Function(Map<String, dynamic> json) test,
    Map<String, dynamic> Function(Map<String, dynamic> json) transform,
  ) {
    return _mutate(() async {
      final rows = await _readAllRows();
      var changed = 0;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row['type'] != messageType || !test(row)) continue;
        final updated = transform(row);
        updated['id'] = row['id'];
        updated['seq'] = row['seq'];
        updated['type'] = messageType;
        rows[i] = updated;
        changed++;
      }
      if (changed > 0) {
        await _writeAll(rows);
      }
      return changed;
    });
  }

  /// 删除命中的消息行,返回删除数。
  ///
  /// 调用方要删一批 id 时,**把整批放进 [test]**（一次读-改-写）；按 id 循环
  /// 调用会把整文件读写重复 N 遍（实测 833KB 的会话逐条删 199 条要 1.5s）。
  Future<int> deleteMessageWhere(
    bool Function(Map<String, dynamic> json) test,
  ) {
    return _mutate(() async {
      final rows = await _readAllRows();
      final before = rows.length;
      rows.removeWhere((r) => r['type'] == messageType && test(r));
      if (rows.length != before) {
        await _writeAll(rows);
      }
      return before - rows.length;
    });
  }

  /// 删除整个会话文件及其回退快照。
  ///
  /// 快照是完整会话副本，删除会话时必须一起删除：否则用户以为已经清掉的
  /// 历史仍留在 `sessions/` 里，且不会出现在列表里，既占磁盘也违背删除语义。
  /// 先删快照再删正文：快照删除失败时正文还在，重试仍能完成整次删除。
  Future<void> deleteFile() {
    return _mutate(() async {
      await _deleteRewindSnapshots();
      if (await file.exists()) {
        await file.delete();
      }
    });
  }

  Future<void> _deleteRewindSnapshots() async {
    final parent = file.parent;
    if (!await parent.exists()) return;
    final prefix = '${file.path}.rewind-';
    await for (final entity in parent.list()) {
      if (entity is! File || !entity.path.startsWith(prefix)) continue;
      await entity.delete();
    }
  }

  /// 只保留最新的 [maxRewindSnapshots] 份快照。
  ///
  /// 按修改时间排序（UUIDv7 在同一毫秒内不保证严格递增）。[keepPath] 是刚
  /// 创建的这份，始终不参与淘汰：文件系统时间精度不足或同毫秒随机序都可能
  /// 让新快照排到最旧，删掉它等于这次回退没有恢复点。删除失败只记日志，
  /// 不能把一次已经成功的回退变成失败（下一次回退会继续尝试清理）。
  Future<void> _pruneRewindSnapshots({required String keepPath}) async {
    final parent = file.parent;
    if (!await parent.exists()) return;
    final prefix = '${file.path}.rewind-';
    final snapshots = <({File file, DateTime modified})>[];
    await for (final entity in parent.list()) {
      if (entity is! File ||
          !entity.path.startsWith(prefix) ||
          entity.path == keepPath) {
        continue;
      }
      try {
        snapshots.add((file: entity, modified: await entity.lastModified()));
      } catch (_) {
        // 快照刚被并发删除：跳过即可。
      }
    }
    final total = snapshots.length + 1;
    if (total <= maxRewindSnapshots) return;
    snapshots.sort((a, b) {
      final byTime = a.modified.compareTo(b.modified);
      return byTime != 0 ? byTime : a.file.path.compareTo(b.file.path);
    });
    final excess = total - maxRewindSnapshots;
    for (final snapshot in snapshots.take(excess)) {
      try {
        await snapshot.file.delete();
      } catch (e) {
        LoggerUtil.w(
          'Failed to prune rewind snapshot ${snapshot.file.path}: $e',
        );
      }
    }
  }

  /// 从文件**尾部向前**扫描读取最近 [count] 条消息行(不含会话元数据行),
  /// 不读整个文件。
  ///
  /// 长对话的 JSONL 可达几百 MB,`readAll` 全量读 + 逐行 jsonDecode 既慢
  /// 又占内存;窗口化(消息列表只持有最近 N 条,向上滚动加载更早)需要
  /// 「读最近 [count] 条」与「读 seq < [beforeSeq] 的最近 [count] 条」两个
  /// 原语,这里用 RandomAccessFile 从末尾向前读块实现,读取量 ≈ 需要
  /// 的字节数,与文件总大小无关。
  ///
  /// 文件行序即消息序,从尾部向前遍历即按 id 降序。块边界可能切断
  /// UTF-8 多字节字符——只切「以 \n 结尾的完整行段」解码,块首到第一个
  /// \n 之间的悬浮半行留在缓冲里等更早的块拼全。文件末尾无换行的最后
  /// 一行按完整行处理。损坏行(空行/非法 JSON)跳过;读完全部块后缓冲里
  /// 剩的是文件首行(会话元数据),不属于消息,直接丢弃。
  ///
  /// 悬浮半行按**剩余长度翻倍**决定下一块读多大:块边界落在一条超长行里
  /// (一行的 json 里能塞几 MB 的 base64 图片)时,逐块把半行抄一遍是平方级,
  /// 翻倍读则把复制量拉回几何级数(实测 3.4MB 的图片行：单页 830ms → 约
  /// 20ms,基准见 `tool/bench_message_loading.dart`),且不会多读半行之前的历史。
  ///
  /// 全程走该文件的串行锁:与 append/整文件重写(update)互斥,避免
  /// 重写窗口内读到中间状态。
  Future<List<Map<String, dynamic>>> loadRecentRows(
    int count, {
    int? beforeSeq,
  }) {
    return _serialized(
      () => _loadRecentRowsUnlocked(count, beforeSeq: beforeSeq),
    );
  }

  /// [loadRecentRows] 的实现,不取锁:供已持锁的修改操作内部调用。
  Future<List<Map<String, dynamic>>> _loadRecentRowsUnlocked(
    int count, {
    int? beforeSeq,
  }) async {
    if (count <= 0 || !await file.exists()) return const [];
    final raf = await file.open();
    try {
      final length = await raf.length();
      final result = <Map<String, dynamic>>[];
      // 已读未切出完整行的字节（开头方向 = 更早，末尾方向 = 更晚）
      var buffer = Uint8List(0);
      var blockSize = _readBlockSize;
      var pos = length;
      while (pos > 0 && result.length < count) {
        final size = math.min(blockSize, pos);
        final start = pos - size;
        await raf.setPosition(start);
        final block = await raf.read(size);
        pos = start;
        final combined = _concatBytes(block, buffer);
        // 从末尾向前切完整行,直到块内没有可切的(悬浮行首留到下一轮)。
        // 索引指针 [end) 单调前移,整块一次线性扫描(不反复 lastIndexOf
        // + sublist 复制,避免 O(n²)——每行只复制行字节本身)
        var end = combined.length;
        while (end > 0 && result.length < count) {
          final nl = combined.lastIndexOf(0x0A, end - 1);
          if (nl < 0) break;
          final lineBytes = combined.sublist(nl + 1, end);
          end = nl;
          if (lineBytes.isNotEmpty) {
            final row = _decodeLineBytes(lineBytes);
            if (row == null || row['type'] != messageType) continue;
            final seq = row['seq'];
            if (beforeSeq == null || seq is int && seq < beforeSeq) {
              result.add(row);
            }
          }
        }
        buffer = combined.sublist(0, end);
        // 还剩下半行 = 这块的边界落在一条很长的行里:下一块按它翻倍读
        blockSize = math.max(_readBlockSize, buffer.length * 2);
      }
      // 所有块读完:缓冲里剩的是文件首行(会话元数据),跳过
      // 逆序收集(最新在前),翻转为升序
      return result.reversed.toList();
    } finally {
      await raf.close();
    }
  }

  /// 单次读块的基准大小。块越大,跨块的半行越少;真正的上限由"半行翻倍"决定。
  static const int _readBlockSize = 65536;

  /// 拼接两段字节（[head] 在前）。用 [Uint8List] 而不是 `List<int>`：一条几 MB
  /// 的图片行在这里不该被放大成每个小整数一个引用。
  static Uint8List _concatBytes(List<int> head, List<int> tail) {
    final joined = Uint8List(head.length + tail.length);
    joined.setRange(0, head.length, head);
    joined.setRange(head.length, joined.length, tail);
    return joined;
  }

  // ─────────────────────────── 内部 ───────────────────────────

  /// 解码单行文本为 JSON Map;损坏行返回 null。
  Map<String, dynamic>? _decodeRow(String line) {
    try {
      final value = jsonDecode(line);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// 解码单行字节为 JSON Map(尾部扫描用);损坏行返回 null。
  Map<String, dynamic>? _decodeLineBytes(List<int> lineBytes) {
    try {
      return _decodeRow(utf8.decode(lineBytes));
    } catch (_) {
      return null;
    }
  }

  /// 读取全部可解析行(按文件行序,跳过损坏行)。
  ///
  /// 按宽松 UTF-8 解码:写到一半断电的行可能截在多字节字符中间,严格解码
  /// (`readAsLines`)会让整个文件读失败,连带会话列表都列不出来。
  Future<List<Map<String, dynamic>>> _readAllRows() async {
    if (!await file.exists()) return [];
    final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final rows = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final row = _decodeRow(line);
      if (row != null) {
        rows.add(row);
      } else {
        skipped++;
      }
    }
    if (skipped > 0) {
      LoggerUtil.w('session ${file.path}: skipped $skipped corrupt line(s)');
    }
    return rows;
  }

  Future<void> _appendRow(Map<String, dynamic> row) async {
    await file.parent.create(recursive: true);
    // 上次追加写到一半(崩溃 / 磁盘满)会留下没有换行的半截行,直接接在
    // 后面会把这条新消息也拼成坏行,被读取时静默丢弃
    final needsNewline = await _endsWithoutNewline();
    final sink = file.openWrite(mode: FileMode.append);
    if (needsNewline) sink.write('\n');
    sink.write(jsonEncode(row));
    sink.write('\n');
    await sink.close();
  }

  Future<bool> _endsWithoutNewline() async {
    if (!await file.exists()) return false;
    final raf = await file.open();
    try {
      final length = await raf.length();
      if (length == 0) return false;
      await raf.setPosition(length - 1);
      return (await raf.readByte()) != 0x0A;
    } finally {
      await raf.close();
    }
  }

  /// 整文件重写:临时文件 + rename 原子替换。GUI 与 TUI 共享数据目录,
  /// 另一进程在重写窗口内读到的要么是旧文件要么是新文件,不会是半截。
  Future<void> _writeAll(List<Map<String, dynamic>> rows) async {
    await file.parent.create(recursive: true);
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(jsonEncode(row));
    }
    await atomicWriteString(file, buf.toString());
  }
}
