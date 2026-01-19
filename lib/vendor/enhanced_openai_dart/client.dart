import 'dart:async';
import 'dart:convert';

import 'package:athena/vendor/enhanced_openai_dart/delta.dart';
import 'package:openai_dart/openai_dart.dart';
// ignore: implementation_imports
import 'package:openai_dart/src/generated/client.dart' as g;

/// 增强版 OpenAI 客户端，支持 reasoning 字段
class EnhancedOpenAIClient extends OpenAIClient {
  EnhancedOpenAIClient({
    super.apiKey,
    super.organization,
    super.beta,
    super.baseUrl,
    super.headers,
    super.queryParams,
    super.client,
  });

  /// 创建增强版非流式聊天完成请求
  Future<EnhancedResponse> createEnhancedChatCompletion({
    required CreateChatCompletionRequest request,
  }) async {
    final response = await makeRequest(
      baseUrl: baseUrl ?? 'https://api.openai.com/v1',
      path: '/chat/completions',
      method: g.HttpMethod.post,
      requestType: 'application/json',
      responseType: 'application/json',
      body: request.copyWith(stream: false),
    );
    var responseJson = json.decode(response.body) as Map<String, dynamic>;
    return EnhancedResponse.fromJson(responseJson);
  }

  /// 创建增强版流式聊天完成请求
  Stream<EnhancedStreamResponse> createEnhancedChatCompletionStream({
    required CreateChatCompletionRequest request,
  }) async* {
    final streamResponse = await makeRequestStream(
      baseUrl: baseUrl ?? 'https://api.openai.com/v1',
      path: '/chat/completions',
      method: g.HttpMethod.post,
      requestType: 'application/json',
      responseType: 'application/json',
      body: request.copyWith(stream: true),
    );
    yield* streamResponse.stream
        .transform(const _OpenAIStreamTransformer())
        .map((json) => EnhancedStreamResponse.fromJson(json));
  }
}

/// SSE 流转换器
class _OpenAIStreamTransformer
    extends StreamTransformerBase<List<int>, Map<String, dynamic>> {
  const _OpenAIStreamTransformer();

  @override
  Stream<Map<String, dynamic>> bind(Stream<List<int>> stream) {
    return stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: ') && !line.endsWith('[DONE]'))
        .map((line) => json.decode(line.substring(6)) as Map<String, dynamic>);
  }
}
