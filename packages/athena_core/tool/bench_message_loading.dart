import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/repository/message_repository.dart';
import 'package:athena_core/storage/id_allocator.dart';
import 'package:athena_core/storage/jsonl_session_repository.dart';
import 'package:athena_core/storage/session_jsonl_store.dart';

/// 会话消息加载的代价基准：**窗口化分页**（现状）vs **整文件全量**。
///
/// 用法（cwd = `packages/athena_core`）：
/// ```
/// dart run tool/bench_message_loading.dart time <file.jsonl>...   # 逐文件量几个路径
/// dart run tool/bench_message_loading.dart rss <窗口条数|all|none> <file.jsonl>
/// dart run tool/bench_message_loading.dart synth <临时目录>       # 合成文本行文件，看随规模的增长
/// ```
///
/// 口径：
/// - **首屏窗口** = `loadRecentRows(messagePageSize + 1)`，即 GUI 打开会话时读的那一条
///   路径（多读 1 条判断还有没有更早的）。
/// - **翻一页** = `loadRecentRows(51, beforeId: 窗口最早那条 id)`。
/// - **全量** = `readMessageRows()` + 逐行 `MessageEntity.fromJson`，等价于
///   `MessageRepository.getMessagesByChatId`。
/// - **轮次扫描** = `loadUserMessageIds()`：现状**已经**在切会话时后台付这笔钱。
/// - 时间取多轮里的**最小值**（排除 GC/调度抖动），内存必须**单开进程**量（RSS 不回收）。
///
/// 只读：所有路径都不写会话文件；`rss` 与 `synth` 只碰传入的临时目录。
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法见文件头注释');
    exitCode = 2;
    return;
  }
  switch (args.first) {
    case 'time':
      for (final path in args.skip(1)) {
        await _timeFile(File(path));
      }
    case 'rss':
      await _rss(args[1], File(args[2]));
    case 'synth':
      await _synthetic(Directory(args[1]));
    case 'pages':
      await _chainedPages(File(args[1]), int.parse(args[2]));
    case 'initial':
      await _initial(
        Directory(args[1]),
        int.parse(args[2]),
        int.parse(args[3]),
      );
    default:
      stderr.writeln('未知子命令：${args.first}');
      exitCode = 2;
  }
}

/// 首屏窗口走的是仓储的新接口（小会话整段 / 大会话尾部一页）。
Future<void> _initial(Directory dir, int chatId, int pageSize) async {
  final repository = JsonlSessionRepository(
    sessionsDir: dir,
    idAllocator: IdAllocator(File('${dir.path}/meta.json')),
  );
  late MessageWindow window;
  final best = await _best(() async {
    window = await repository.loadInitialMessages(chatId, pageSize: pageSize);
  }, runs: 5);
  final file = File('${dir.path}/$chatId.jsonl');
  stdout.writeln(
    '$chatId.jsonl  文件 ${await file.exists() ? _mb(await file.length()) : '不存在'}  '
    '首屏 ${_ms(best)}  '
    '拿到 ${window.messages.length} 条  hasOlder=${window.hasOlder}'
    '${window.hasOlder ? '（仍分页）' : '（整段，不分页）'}',
  );
}

/// 连续翻 [pages] 页（宿主 `_selectTurn` 最多向上翻 8 页去补历史），量点一轮的等待。
Future<void> _chainedPages(File file, int pages) async {
  final store = _store(file);
  var window = await store.loadRecentRows(51);
  final watch = Stopwatch()..start();
  var total = window.length;
  for (var i = 0; i < pages; i++) {
    final beforeId = window.isEmpty ? null : window.first['id'] as int?;
    if (beforeId == null) break;
    window = await store.loadRecentRows(51, beforeId: beforeId);
    if (window.isEmpty) break;
    total += window.length;
  }
  watch.stop();
  stdout.writeln(
    '${file.path.split('/').last}  连续翻 $pages 页  累计 $total 条  '
    '${_ms(watch.elapsedMicroseconds / 1000)}  （每页均值 '
    '${_ms(watch.elapsedMicroseconds / 1000 / pages)}）',
  );
}

SessionJsonlStore _store(File file) => SessionJsonlStore(
  file: file,
  idAllocator: IdAllocator(File('${file.path}.ids')),
);

Future<double> _best(Future<void> Function() action, {int runs = 7}) async {
  final samples = <double>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    await action();
    watch.stop();
    samples.add(watch.elapsedMicroseconds / 1000);
  }
  samples.sort();
  return samples.first;
}

Future<double> _median(Future<void> Function() action, {int runs = 7}) async {
  final samples = <double>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    await action();
    watch.stop();
    samples.add(watch.elapsedMicroseconds / 1000);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

String _ms(double value) => '${value.toStringAsFixed(1)}ms';

String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(2)}MB';

/// 把一个文件里"分页那两条路径"与"全量"的耗时摆在一起。
Future<void> _timeFile(File file) async {
  final store = _store(file);
  final size = await file.length();
  final allRows = await store.readMessageRows();
  final firstIds = [
    for (final row in allRows)
      if (row['role'] == 'user') row['id'],
  ];
  final window = await store.loadRecentRows(51);
  final beforeId = window.isEmpty ? null : window.first['id'] as int?;

  var lastPage = <Map<String, dynamic>>[];
  var lastHeld = <MessageEntity>[];
  final firstPage = await _best(() async {
    await store.loadRecentRows(51);
  });
  final firstPageMedian = await _median(() async {
    await store.loadRecentRows(51);
  });
  final nextPage = await _best(() async {
    if (beforeId != null) {
      lastPage = await store.loadRecentRows(51, beforeId: beforeId);
    }
  });
  final full = await _best(() async {
    final rows = await store.readMessageRows();
    lastHeld = [for (final row in rows) MessageEntity.fromJson(row)];
  }, runs: 5);
  final scan = await _best(() async {
    await store.loadUserMessageIds();
  }, runs: 5);

  final pageIds = [for (final row in lastPage) row['id']];
  final pageOldest = pageIds.isEmpty ? null : pageIds.first;
  final hitHead = pageOldest != null && firstIds.isNotEmpty
      ? pageOldest == firstIds.first
      : false;

  stdout.writeln(
    '${file.path.split('/').last}  文件 ${_mb(size)}  消息行 ${allRows.length}\n'
    '    首屏窗口(51 条) 最快 ${_ms(firstPage)} / 中位 ${_ms(firstPageMedian)}'
    '   翻一页(51 条) 最快 ${_ms(nextPage)}'
    '   全量 ${_ms(full)}'
    '   轮次扫描 ${_ms(scan)}\n'
    '    翻页诊断：返回 ${lastPage.length} 条，最早 id $pageOldest'
    '${hitHead ? '（已扫到文件头 = 整文件反向扫描）' : ''}'
    '   全量/首屏最快比 ${(full / firstPage).toStringAsFixed(1)}x'
    '   持有实体 ${lastHeld.length}',
  );
}

/// 单场景进程 RSS：`none`（基线）/ `窗口 51` / `all`。
Future<void> _rss(String mode, File file) async {
  final store = _store(file);
  final base = ProcessInfo.currentRss;
  List<MessageEntity> held = const [];
  var rows = 0;
  if (mode == 'all') {
    final all = await store.readMessageRows();
    held = [for (final row in all) MessageEntity.fromJson(row)];
    rows = held.length;
  } else if (mode != 'none') {
    final page = await store.loadRecentRows(int.parse(mode));
    held = [for (final row in page) MessageEntity.fromJson(row)];
    rows = held.length;
  }
  // 防优化：真的用一下
  final chars = held.fold<int>(0, (sum, m) => sum + m.content.length);
  stdout.writeln(
    '${file.path.split('/').last}  模式=$mode  持有 $rows 条  内容字符 $chars\n'
    '    RSS 基线 ${_mb(base)} → 之后 ${_mb(ProcessInfo.currentRss)}'
    '   增量 ${_mb(ProcessInfo.currentRss - base)}',
  );
}

/// 合成"文本为主"的长会话（行密度按真实文件：约 8KB/行），看规模曲线。
Future<void> _synthetic(Directory dir) async {
  await dir.create(recursive: true);
  const perRow = 8000; // ≈ 252.jsonl 的每行文本量
  for (final rowCount in [500, 2000, 5000, 20000]) {
    final file = File('${dir.path}/synth_$rowCount.jsonl');
    final sink = file.openWrite();
    sink.writeln(
      jsonEncode({'type': 'chat', 'id': 1, 'title': 'synth', 'model_id': 1}),
    );
    final filler = 'x' * perRow;
    for (var i = 1; i <= rowCount; i++) {
      final role = i.isOdd ? 'user' : 'assistant';
      sink.writeln(
        jsonEncode({
          'type': 'message',
          'id': i,
          'chat_id': 1,
          'role': role,
          'content': 'row $i $filler',
          'reasoning_content': '',
          'reasoning': 0,
          'image_urls': '',
          'reference': '',
          'tool_calls': '',
          'tool_results': '',
          'compacted': 0,
        }),
      );
    }
    await sink.close();
    await _timeFile(file);
  }
}
