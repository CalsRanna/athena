import 'dart:convert';
import 'dart:io';

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
    final id = await save(text);
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

  Future<void> restore(String raw, {required String modelResult}) async {
    _references[_digest(modelResult)] = await save(raw);
  }

  /// Short, recoverable replacement for an older result under context pressure.
  Future<String> reference(String modelResult) async {
    // Recognize only previews created/restored by us, not text that happens to
    // look like a reference in an untrusted command or web response.
    final existing = _references[_digest(modelResult)];
    final id = existing ?? await save(modelResult);
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
