import 'dart:convert';
import 'dart:io';

import 'package:athena_core/util/logger_util.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Full tool outputs, addressed by content so replay produces stable references.
/// Frontends supply an application data directory; tests can use memory storage.
class ToolOutputStore {
  ToolOutputStore({this.directory});

  final Directory? directory;
  final Map<String, String> _memory = {};
  final Map<String, Future<void>> _writes = {};
  final Map<String, String> _references = {};

  static const inlineLimit = 24000;
  static const previewLimit = 2000;
  static const pageLimit = 12000;
  static final _validId = RegExp(r'^[a-f0-9]{64}$');
  String _digest(String text) => sha256.convert(utf8.encode(text)).toString();

  Future<String> save(String text) async {
    final bytes = utf8.encode(text);
    final id = sha256.convert(bytes).toString();
    if (directory == null) {
      _memory[id] = text;
    } else {
      final pending = _writes.putIfAbsent(id, () async {
        await directory!.create(recursive: true);
        final file = File(p.join(directory!.path, '$id.txt'));
        if (!await file.exists()) {
          final temporary = File('${file.path}.tmp');
          await temporary.writeAsBytes(bytes, flush: true);
          await temporary.rename(file.path);
        }
      });
      try {
        await pending;
      } finally {
        _writes.remove(id);
      }
    }
    return id;
  }

  Future<({String modelResult, String? outputId})> prepare(String text) async {
    // length is a cheap fast path; pagination counts Unicode code points.
    if (text.length <= inlineLimit || text.runes.length <= inlineLimit) {
      return (modelResult: text, outputId: null);
    }
    final String id;
    try {
      id = await save(text);
    } catch (error) {
      return (modelResult: _unsavedOutputNotice(text, error), outputId: null);
    }
    final preview = String.fromCharCodes(text.runes.take(previewLimit));
    final modelResult =
        '[tool_output id=$id]\n'
        'Full output saved (${text.runes.length} characters). '
        'Only the first $previewLimit characters are shown below; '
        'any line ranges in the preview describe the saved output.\n'
        'Continue with tool_output_read(output_id="$id", '
        'offset=$previewLimit, limit=6000). Do not rerun the original tool '
        'to retrieve missing output.\n\n$preview';
    _references[_digest(modelResult)] = id;
    return (modelResult: modelResult, outputId: id);
  }

  /// 超长输出落盘失败时的降级结果。
  ///
  /// 落盘是超长输出唯一的读回通道，它失败本身不该冒泡终止整个 run：prepare
  /// 在工具结果装配阶段被调用，不在工具执行的 try 里，异常会一路逃出去，连带
  /// 丢掉同一轮并行组里已经完成的结果。内容还在手里，就把能内联的那部分交还
  /// 模型，并明说这部分读不回来、要换更窄的命令重跑。
  ///
  /// 预览给到 inlineLimit，而不是成功路径上的 previewLimit：成功路径后面还有
  /// `tool_output_read` 兜底，这里没有，能多给一点是一点。提示文案多出的几百
  /// 字符会让这一条略高于 inlineLimit，这是刻意的。
  String _unsavedOutputNotice(String text, Object error) {
    final preview = String.fromCharCodes(text.runes.take(inlineLimit));
    return '[tool_output not saved]\n'
        'This output is ${text.runes.length} characters, above the '
        '$inlineLimit-character inline limit, and saving it failed: $error. '
        'Only the first $inlineLimit characters are shown below, and '
        'tool_output_read cannot retrieve the rest. '
        'Re-run the command with a narrower scope (head / tail / grep) to read '
        'a specific part.\n\n$preview';
  }

  Future<void> restore(String raw, {required String modelResult}) async {
    try {
      _references[_digest(modelResult)] = await save(raw);
    } catch (error) {
      // 读不回原文时让消息保持压缩形态即可，之后的 reference() 会再试一次；
      // 为一次写盘失败终止整个 run 不划算。
      LoggerUtil.w('Failed to restore tool output: $error');
    }
  }

  /// Short, recoverable replacement for an older result under context pressure.
  Future<String> reference(String modelResult) async {
    // Recognize only previews created/restored by us, not text that happens to
    // look like a reference in an untrusted command or web response.
    final existing = _references[_digest(modelResult)];
    String? id = existing;
    if (id == null) {
      try {
        id = await save(modelResult);
      } catch (error) {
        // 压不下去就把原文原样交还：宁可由上下文预算检查给出一次明确的
        // 「装不下」，也不要在这里悄悄截掉内容。
        LoggerUtil.w('Failed to reference tool output: $error');
        return modelResult;
      }
    }
    return '[tool_output id=$id]\n'
        'Output omitted from this request to fit the context window. '
        'Read it with tool_output_read(output_id="$id", offset=0, limit=6000).';
  }

  Future<ToolOutputPage> read(
    String id, {
    int offset = 0,
    int limit = 6000,
  }) async {
    if (!_validId.hasMatch(id)) throw ArgumentError('Invalid output_id');
    if (offset < 0 || limit < 1 || limit > pageLimit) {
      throw ArgumentError('offset must be >= 0; limit must be 1-$pageLimit');
    }
    final pending = _writes[id];
    if (pending != null) await pending;
    final Stream<String> chunks;
    if (directory == null) {
      final text = _memory[id];
      if (text == null) throw StateError('Saved output not found: $id');
      chunks = Stream.value(text);
    } else {
      final file = File(p.join(directory!.path, '$id.txt'));
      if (!await file.exists()) throw StateError('Saved output not found: $id');
      chunks = file.openRead().transform(utf8.decoder);
    }
    // Do not split lines: a single minified JSON line may contain megabytes.
    final characters = await chunks
        .expand((chunk) => chunk.runes)
        .skip(offset)
        .take(limit + 1)
        .toList();
    final hasMore = characters.length > limit;
    if (hasMore) characters.removeLast();
    return ToolOutputPage(
      text: String.fromCharCodes(characters),
      nextOffset: offset + characters.length,
      hasMore: hasMore,
    );
  }
}

class ToolOutputPage {
  const ToolOutputPage({
    required this.text,
    required this.nextOffset,
    required this.hasMore,
  });

  final String text;
  final int nextOffset;
  final bool hasMore;
}
