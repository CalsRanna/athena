import 'dart:async';

import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart';
import 'package:html_parser_plus/html_parser_plus.dart';
import 'package:http/http.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;

class SummaryApi {
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

  Stream<ChatCompletionStreamResponseDelta> summarize({
    required List<ChatCompletionMessage> messages,
    required Model model,
    required Provider provider,
  }) async* {
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/athena',
      'X-Title': 'Athena',
    };
    var client = OpenAIClient(
      apiKey: provider.key,
      baseUrl: provider.url,
      headers: headers,
    );
    var request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model.value),
      messages: messages,
    );
    var response = client.createChatCompletionStream(request: request);
    await for (final chunk in response) {
      if (chunk.choices.isEmpty) continue;
      yield chunk.choices.first.delta;
    }
  }
}
