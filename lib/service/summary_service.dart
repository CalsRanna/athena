import 'dart:async';

import 'package:athena/entity/provider_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:html_parser_plus/html_parser_plus.dart';
import 'package:http/http.dart';
import 'package:openai_dart/openai_dart.dart';

/// SummaryService 负责网页摘要相关的网络请求
class SummaryService {
  /// 解析网页文档
  Future<Map<String, String>> parseDocument(String url) async {
    var uri = Uri.parse(url);
    var response = await get(uri);
    var parser = HtmlParser();
    var scriptSource = r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>';
    var styleSource = r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>';
    var filteredHtml = response.body
        .replaceAll(RegExp(scriptSource, multiLine: true), '')
        .replaceAll(RegExp(styleSource, multiLine: true), '');
    var node = parser.parse(filteredHtml);
    var title = parser.query(node, '//title@text');
    var icon = '${uri.scheme}://${uri.host}/favicon.ico';
    var html = parser.query(node, '//@text');
    return {'html': html, 'icon': icon, 'title': title};
  }

  /// 生成摘要流
  Stream<ChatCompletionStreamResponseDelta> summarize({
    required List<ChatCompletionMessage> messages,
    required ModelEntity model,
    required ProviderEntity provider,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.modelId),
      messages: messages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta;
    }
  }
}
