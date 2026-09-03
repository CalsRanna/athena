import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/service/llm_client.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart';

/// SummaryService 负责网页摘要相关的网络请求
class SummaryService {
  /// 请求超时与响应体上限：慢速/超大页面不得长时间挂起或撑爆内存。
  static const _timeout = Duration(seconds: 30);
  static const _maxBodyBytes = 2 * 1024 * 1024; // 2MB

  final LlmClient _llmClient;

  SummaryService({required LlmClient llmClient}) : _llmClient = llmClient;

  /// 解析网页文档
  Future<Map<String, String>> parseDocument(String url) async {
    var uri = Uri.parse(url);
    final client = http.Client();
    late http.StreamedResponse streamed;
    try {
      streamed = await client.send(http.Request('GET', uri)).timeout(_timeout);
    } catch (_) {
      client.close();
      rethrow;
    }

    // 流式读取，超过上限即截断（脚本/style 标签会被后续正则剔除，
    // 截断后仍是可解析的 HTML）。
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in streamed.stream.timeout(_timeout)) {
        if (bytes.length >= _maxBodyBytes) break;
        final remaining = _maxBodyBytes - bytes.length;
        bytes.add(chunk.length <= remaining
            ? chunk
            : chunk.sublist(0, remaining));
      }
    } finally {
      client.close();
    }

    var body = utf8.decode(bytes.toBytes(), allowMalformed: true);
    var scriptSource = r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>';
    var styleSource = r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>';
    var filteredHtml = body
        .replaceAll(RegExp(scriptSource, multiLine: true), '')
        .replaceAll(RegExp(styleSource, multiLine: true), '');
    var doc = html_parser.parse(filteredHtml);
    var title = doc.querySelector('title')?.text ?? '';
    var icon = '${uri.scheme}://${uri.host}/favicon.ico';
    var html = doc.querySelector('body')?.text ?? '';
    return {'html': html, 'icon': icon, 'title': title};
  }

  /// 生成摘要流
  Stream<ChatDelta> summarize({
    required List<ChatMessage> messages,
    required ModelEntity model,
    required ProviderEntity provider,
  }) async* {
    var request = ChatCompletionCreateRequest(
      model: model.modelId,
      messages: messages,
    );
    var stream = _llmClient.stream(provider: provider, request: request);
    await for (final chunk in stream) {
      if (chunk.choices == null || chunk.choices!.isEmpty) continue;
      yield chunk.choices!.first.delta;
    }
  }
}
