import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'html_to_markdown.dart';
import 'tool_interface.dart';

class WebFetchTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  static const _maxResponseBytes = 200 * 1024; // 200KB
  static const _defaultTimeout = Duration(seconds: 30);

  @override
  String get name => 'web_fetch';

  @override
  String get description => 'Fetch content from a URL and return it as '
      'Markdown (default) or raw HTML. '
      'Markdown mode strips unnecessary tags and converts the page to '
      'readable text — ideal for most tasks. '
      'HTML mode preserves the original markup for structural analysis. '
      'Response is capped at 200KB.\n'
      'Referer and X-Title headers may be added automatically by the client.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The URL to fetch. Must be http or https.',
          },
          'method': {
            'type': 'string',
            'enum': ['GET', 'POST'],
            'description': 'HTTP method. Defaults to GET.',
          },
          'format': {
            'type': 'string',
            'enum': ['markdown', 'html'],
            'description':
                'Output format. "markdown" (default) converts HTML to '
                'clean readable text. "html" returns the raw HTML (useful '
                'for analyzing page structure, extracting specific elements, '
                'or debugging markup).',
          },
          'headers': {
            'type': 'object',
            'description': 'Optional HTTP headers as key-value pairs.',
          },
          'body': {
            'type': 'string',
            'description': 'Request body for POST requests.',
          },
        },
        'required': ['url'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {void Function(String)? onUpdate}) async {
    final url = args['url'] as String;
    final method = args['method'] as String? ?? 'GET';
    final format = args['format'] as String? ?? 'markdown';
    final headers = (args['headers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        {};
    final body = args['body'] as String?;

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'Error: Invalid URL: $url';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Error: Only http and https URLs are allowed';
    }
    try {
      final methodUpper = method.toUpperCase();
      if (methodUpper != 'GET' && methodUpper != 'POST') {
        return 'Error: Unsupported method: $method';
      }

      final client = http.Client();
      final request = http.Request(methodUpper, uri)
        ..headers.addAll(headers);
      if (methodUpper == 'POST' && body != null) {
        request.body = body;
      }

      late http.StreamedResponse streamed;
      try {
        streamed = await client.send(request).timeout(_defaultTimeout);
      } catch (_) {
        client.close();
        rethrow;
      }

      // 流式读取响应体：超过上限即停止接收，避免超大文件
      // （如数百 MB 的下载链接）被整个缓冲进内存。
      final bodyBytes = BytesBuilder(copy: false);
      var overLimit = false;
      try {
        await for (final chunk in streamed.stream.timeout(_defaultTimeout)) {
          if (bodyBytes.length >= _maxResponseBytes) {
            overLimit = true;
            break;
          }
          final remaining = _maxResponseBytes - bodyBytes.length;
          bodyBytes.add(chunk.length <= remaining
              ? chunk
              : chunk.sublist(0, remaining));
        }
      } finally {
        client.close();
      }

      final knownTotal = streamed.contentLength;
      final tooLarge =
          (knownTotal ?? bodyBytes.length) > _maxResponseBytes || overLimit;
      final raw =
          _decodeBody(bodyBytes.toBytes(), streamed.headers['content-type']);

      // Markdown 模式且响应看起来像 HTML 时才转换
      final contentType = streamed.headers['content-type'] ?? '';
      final looksLikeHtml =
          contentType.contains('text/html') || _hasHtmlTags(raw);

      final output = (format == 'markdown' && looksLikeHtml)
          ? htmlToMarkdown(raw)
          : raw;

      final result = StringBuffer();
      result.writeln('Status: ${streamed.statusCode}');
      if (streamed.reasonPhrase != null &&
          streamed.reasonPhrase!.isNotEmpty) {
        result.writeln('Reason: ${streamed.reasonPhrase}');
      }
      result.writeln(
          'Content-Type: ${contentType.isNotEmpty ? contentType : '(unknown)'}');
      result.writeln();

      if (tooLarge) {
        result.writeln(output);
        result.writeln();
        final totalNote = knownTotal != null
            ? '${knownTotal ~/ 1024}KB'
            : '>${_maxResponseBytes ~/ 1024}KB';
        result.writeln(
            '[Response truncated: limit ${_maxResponseBytes ~/ 1024}KB / '
            '$totalNote total]');
        result.writeln(
            'Hint: to reduce payload, use a more specific URL or API '
            'endpoint, add query parameters to filter results, or retry '
            'with Accept-Encoding: gzip if the server supports it.');
      } else {
        result.write(output);
      }

      return result.toString();
    } on http.ClientException catch (e) {
      return 'Error: Request failed: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 按响应 Content-Type 的 charset 解码响应体；未指定时用 latin1
  /// （与 http 包 Response.body 的默认行为一致）。
  static String _decodeBody(List<int> bytes, String? contentType) {
    final match = contentType == null
        ? null
        : RegExp(r'charset=([\w-]+)', caseSensitive: false)
            .firstMatch(contentType);
    final encoding = match != null ? Encoding.getByName(match[1]!) : null;
    // 各具体 codec 的 allowMalformed 默认均为 true，无需显式传入。
    return (encoding ?? latin1).decode(bytes);
  }

  /// 简单试探：检测文本是否包含 HTML 标签。
  static bool _hasHtmlTags(String text) {
    final upper = text.length > 2000 ? text.substring(0, 2000) : text;
    return RegExp(r'<\s*(html|head|body|div|p|h[1-6]|span|a\s|table)',
            caseSensitive: false)
        .hasMatch(upper);
  }
}
