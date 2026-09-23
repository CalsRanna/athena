import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:athena_core/storage/file_lock.dart';
import 'package:athena_core/storage/id_allocator.dart';
import 'package:athena_core/storage/serial_lock.dart';

/// 单会话文件存储:`sessions/{chatId}.jsonl`。
///
/// 一个对话一个文件,首行是会话元数据,后续行是消息,行序即消息序:
/// ```jsonl
/// {"type":"chat","id":1,"title":"...","model_id":1,...}
/// {"type":"message","id":1,"chat_id":1,"role":"user","content":"..."}
/// {"type":"message","id":2,"chat_id":1,"role":"assistant","content":"..."}
/// ```
///
/// 设计要点:
/// - **单写者锁**:所有修改在单次锁内完成(读-改-写原子),流式期间
///   的 update(整文件重写)与 append 并发时不丢行(锁是实例字段,调用方
///   必须按文件缓存共享实例,锁才能跨调用生效)
/// - **跨进程文件锁**:GUI 与 TUI 共享目录,修改再套一层 `.lock` 排它,
///   另一进程的重写(rename 换 inode)不会吞掉本进程的 append
/// - **原子写**:整文件重写走临时文件 + rename;读不加锁,读到的要么是
///   旧文件要么是新文件
/// - **损坏容错**:损坏行跳过,chat 记录缺失时按无会话处理
/// - 行更新采用整文件重写:会话数据规模有限,重写简单可靠
class SessionJsonlStore {
  SessionJsonlStore({required this.file, required this.idAllocator});

  final File file;
  final IdAllocator idAllocator;

  Future<void>? _lock;

  static const chatType = 'chat';
  static const messageType = 'message';

  /// 进程内串行(读写都排队,读不会夹在本进程写的中间)。
  Future<T> _serialized<T>(Future<T> Function() action) {
    return serialLock(_lock, action, (f) => _lock = f);
  }

  /// 修改:进程内串行 + 跨进程文件锁。
  Future<T> _mutate<T>(Future<T> Function() action) {
    return _serialized(() => withFileLock(lockFileFor(file), action));
  }

  // ─────────────────────────── 会话元数据(首行) ───────────────────────────

  /// 读取会话元数据;文件缺失/损坏时返回 null。
  Future<Map<String, dynamic>?> readChatRow() {
    return _serialized(() async {
      final rows = await _readAllRows();
      for (final row in rows) {
        if (row['type'] == chatType) return row;
      }
      return null;
    });
  }

  /// 替换首行的会话元数据;不存在则插入到文件头。
  Future<void> writeChatRow(Map<String, dynamic> row) {
    return _mutate(() async {
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
  Future<Map<String, dynamic>?> updateChatRow(
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) {
    return _mutate(() async {
      final rows = await _readAllRows();
      final index = rows.indexWhere((r) => r['type'] == chatType);
      if (index < 0) return null;
      final updated = transform(rows[index]);
      updated['id'] = rows[index]['id'];
      updated['type'] = chatType;
      rows[index] = updated;
      await _writeAll(rows);
      return updated;
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
  Future<List<int>> loadUserMessageIds() {
    return _serialized(() async {
      if (!await file.exists()) return const [];
      final ids = <int>[];
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
        if (id is int) ids.add(id);
      }
      return ids;
    });
  }

  /// 分配 id 并追加一条消息,返回新 id。
  Future<int> appendMessage(Map<String, dynamic> row) {
    return _mutate(() async {
      final id = await idAllocator.next(file.path);
      row['id'] = id;
      row['type'] = messageType;
      await _appendRow(row);
      return id;
    });
  }

  /// 按 id 整行替换消息(不存在则追加)。
  Future<void> replaceMessage(int id, Map<String, dynamic> row) {
    return _mutate(() async {
      final rows = await _readAllRows();
      row['id'] = id;
      row['type'] = messageType;
      final index = rows.indexWhere(
        (r) => r['type'] == messageType && r['id'] == id,
      );
      if (index >= 0) {
        rows[index] = row;
      } else {
        rows.add(row);
      }
      await _writeAll(rows);
    });
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
  Future<int> deleteMessageWhere(bool Function(Map<String, dynamic> json) test) {
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

  /// 删除整个会话文件。
  Future<void> deleteFile() {
    return _mutate(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });
  }

  /// 从文件**尾部向前**扫描读取最近 [count] 条消息行(不含会话元数据行),
  /// 不读整个文件。
  ///
  /// 长对话的 JSONL 可达几百 MB,`readAll` 全量读 + 逐行 jsonDecode 既慢
  /// 又占内存;窗口化(消息列表只持有最近 N 条,向上滚动加载更早)需要
  /// 「读最近 [count] 条」与「读 id < [beforeId] 的最近 [count] 条」两个
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
    int? beforeId,
  }) {
    return _serialized(() async {
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
              final id = row['id'];
              if (beforeId == null || id is int && id < beforeId) {
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
    });
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
  Future<List<Map<String, dynamic>>> _readAllRows() async {
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    final rows = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final row = _decodeRow(line);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  Future<void> _appendRow(Map<String, dynamic> row) async {
    await file.parent.create(recursive: true);
    final sink = file.openWrite(mode: FileMode.append);
    sink.write(jsonEncode(row));
    sink.write('\n');
    await sink.close();
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
