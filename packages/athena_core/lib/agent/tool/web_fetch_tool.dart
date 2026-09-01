import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/agent/cancel_token.dart';

import 'html_to_markdown.dart';
import 'tool_interface.dart';

class WebFetchTool implements Tool, CancellableTool {
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  static const _maxResponseBytes = 200 * 1024; // 200KB
  static const _defaultTimeout = Duration(seconds: 30);
  static const _maxRedirects = 5;

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
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) =>
      _execute(args, onUpdate: onUpdate);

  @override
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) =>
      _execute(
        args,
        onUpdate: onUpdate,
        cancelSignal: cancelSignal,
      );

  Future<String> _execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    Future<void>? cancelSignal,
  }) async {
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
    var cancelled = false;
    try {
      final methodUpper = method.toUpperCase();
      if (methodUpper != 'GET' && methodUpper != 'POST') {
        return 'Error: Unsupported method: $method';
      }

      final client = HttpClient();
      var completed = false;
      if (cancelSignal != null) {
        unawaited(cancelSignal.then((_) {
          cancelled = true;
          if (!completed) client.close(force: true);
        }));
      }
      late HttpClientResponse response;
      try {
        var currentUri = uri;
        var currentMethod = methodUpper;
        var redirects = 0;
        while (true) {
          final blocked = _blockedReason(currentUri);
          if (blocked != null) {
            completed = true;
            client.close();
            return 'Error: Blocked: $blocked ($url)';
          }
          final request = await client
              .openUrl(currentMethod, currentUri)
              .timeout(_defaultTimeout);
          // Dart 3.12 起 followRedirects 是 request 级属性（HttpClient 级
          // 配置已移除）。关闭自动跟跳、手动跟随，保证每一跳都重新做
          // 字面量地址校验（package:http 的 IOClient 无法关闭跟跳）。
          request.followRedirects = false;
          headers.forEach(request.headers.add);
          if (currentMethod == 'POST' && body != null) {
            final bytes = utf8.encode(body);
            request.contentLength = bytes.length;
            request.add(bytes);
          }
          response = await request.close().timeout(_defaultTimeout);
          if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers.value('location');
            await response.drain<void>();
            if (location == null || redirects >= _maxRedirects) {
              break; // 无跳转目标或超限：把当前 3xx 响应当最终响应返回
            }
            currentUri = currentUri.resolve(location);
            redirects++;
            // 301/302/303 按惯例转 GET（丢弃 body）；307/308 保留原方法
            if (response.statusCode != 307 && response.statusCode != 308) {
              currentMethod = 'GET';
            }
            continue;
          }
          break;
        }
      } catch (_) {
        completed = true;
        client.close();
        rethrow;
      }

      // 流式读取响应体：超过上限即停止接收，避免超大文件
      // （如数百 MB 的下载链接）被整个缓冲进内存。
      final bodyBytes = BytesBuilder(copy: false);
      var overLimit = false;
      try {
        await for (final chunk in response.timeout(_defaultTimeout)) {
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
        completed = true;
        client.close(force: cancelled);
      }

      // dart:io 无 content-length 时为 -1
      final knownTotal = response.contentLength;
      final tooLarge =
          (knownTotal > 0 ? knownTotal : bodyBytes.length) > _maxResponseBytes ||
              overLimit;
      final raw =
          _decodeBody(bodyBytes.toBytes(), response.headers.value('content-type'));

      // Markdown 模式且响应看起来像 HTML 时才转换
      final contentType = response.headers.value('content-type') ?? '';
      final looksLikeHtml =
          contentType.contains('text/html') || _hasHtmlTags(raw);

      final output = (format == 'markdown' && looksLikeHtml)
          ? htmlToMarkdown(raw)
          : raw;

      final result = StringBuffer();
      result.writeln('Status: ${response.statusCode}');
      if (response.reasonPhrase.isNotEmpty) {
        result.writeln('Reason: ${response.reasonPhrase}');
      }
      result.writeln(
          'Content-Type: ${contentType.isNotEmpty ? contentType : '(unknown)'}');
      result.writeln();

      if (tooLarge) {
        result.writeln(output);
        result.writeln();
        final totalNote = knownTotal > 0
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
    } on SocketException catch (e) {
      if (cancelled) throw const CancelledException();
      return 'Error: Request failed: ${e.message}';
    } on HttpException catch (e) {
      if (cancelled) throw const CancelledException();
      return 'Error: Request failed: ${e.message}';
    } on TimeoutException catch (e) {
      if (cancelled) throw const CancelledException();
      return 'Error: Request timed out: ${e.message}';
    } catch (e) {
      if (cancelled) throw const CancelledException();
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

  /// SSRF 字面量地址检查。返回拒绝原因；null = 放行。
  ///
  /// 刻意**不做 DNS 解析**：fake-ip 代理环境（Clash/Surge 等）下域名由
  /// 代理层解析为假 IP，按解析结果拦截会误伤所有正常访问。因此只检查：
  /// - 主机名是 `localhost` / `.local` 结尾
  /// - 主机名是字面 IP（[InternetAddress.tryParse]，不触发 lookup）且
  ///   命中私网/保留网段
  /// - 纯数字 / 十六进制主机名（整数 IP 与 0x 形式，如 `2130706433`，
  ///   解析器会当作 IP 而非域名）
  ///
  /// 已知局限：恶意域名解析到内网（DNS rebinding）在直连模式下仍可
  /// 绕过——fake-ip 代理下由代理层缓解；直连场景由 POST/自定义 headers
  /// 弹窗（PermissionService）与手动重定向校验兜底。
  static String? _blockedReason(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return 'empty host';
    if (host == 'localhost' || host.endsWith('.local')) {
      return 'localhost / .local hosts are not allowed';
    }
    // 整数/十六进制 IP 形态（点分 IPv6 字面量会被 tryParse 正常识别）
    if (RegExp(r'^(0x[0-9a-f]+|\d+)$').hasMatch(host)) {
      return 'numeric IP address is not allowed';
    }
    final addr = InternetAddress.tryParse(host);
    if (addr != null && _isPrivateOrReserved(addr)) {
      return 'private/internal address $host is not allowed';
    }
    return null;
  }

  /// 判断字面 IP 是否属于私网/保留网段。
  static bool _isPrivateOrReserved(InternetAddress addr) {
    final bytes = addr.rawAddress;
    if (addr.type == InternetAddressType.IPv4) {
      if (bytes.length != 4) return false;
      final b0 = bytes[0];
      final b1 = bytes[1];
      if (b0 == 0) return true; // 0.0.0.0/8
      if (b0 == 10) return true; // 10.0.0.0/8
      if (b0 == 127) return true; // 127.0.0.0/8（loopback）
      if (b0 == 169 && b1 == 254) return true; // 169.254.0.0/16（含云元数据）
      if (b0 == 172 && b1 >= 16 && b1 <= 31) return true; // 172.16.0.0/12
      if (b0 == 100 && b1 >= 64 && b1 <= 127) {
        return true; // 100.64.0.0/10 CGNAT
      }
      if (b0 == 192 && b1 == 168) return true; // 192.168.0.0/16
      return false;
    }
    // IPv6
    if (bytes.length != 16) return false;
    final isZero = bytes.every((b) => b == 0);
    final isLoopback =
        bytes[15] == 1 && bytes.take(15).every((b) => b == 0);
    if (isZero || isLoopback) return true; // :: 与 ::1
    if (bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80) {
      return true; // fe80::/10 link-local
    }
    if ((bytes[0] & 0xFE) == 0xFC) return true; // fc00::/7 unique local
    return false;
  }
}
