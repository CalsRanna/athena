import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/html_to_markdown.dart';
import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:meta/meta.dart';

class WebFetchTool extends Tool implements CancellableTool {
  WebFetchTool({Duration timeout = _defaultTimeout}) : _timeout = timeout;

  final Duration _timeout;
  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  static const _maxResponseBytes = 200 * 1024; // 200KB
  static const _defaultTimeout = Duration(seconds: 30);
  static const _maxRedirects = 5;

  @override
  String get name => 'web_fetch';

  @override
  String get description =>
      'Fetch content from a URL and return it as '
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
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) => _execute(args, onUpdate: onUpdate);

  @override
  Future<ToolExecutionResult> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) => _execute(args, onUpdate: onUpdate, cancelSignal: cancelSignal);

  Future<ToolExecutionResult> _execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    Future<void>? cancelSignal,
  }) async {
    final url = args['url'] as String;
    final method = args['method'] as String? ?? 'GET';
    final format = args['format'] as String? ?? 'markdown';
    final headers =
        (args['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        {};
    final body = args['body'] as String?;

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ToolExecutionResult.error('Error: Invalid URL: $url');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const ToolExecutionResult.error(
        'Error: Only http and https URLs are allowed',
      );
    }
    final client = HttpClient();
    var cancelled = false;
    try {
      // 整次请求共用一个截止时间，包含重定向排空和响应体；关闭 client 只负责
      // 资源清理，取消还必须直接赢得竞速，不能依赖底层流一定会抛错。
      return await Future.any<ToolExecutionResult>([
        _fetch(client, uri, method.toUpperCase(), headers, body, format),
        if (cancelSignal != null)
          cancelSignal.then<ToolExecutionResult>((_) {
            cancelled = true;
            throw const CancelledException();
          }),
      ]).timeout(_timeout);
    } on CancelledException {
      rethrow;
    } catch (e) {
      if (cancelled) throw const CancelledException();
      return ToolExecutionResult.error('Error: Request failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<ToolExecutionResult> _fetch(
    HttpClient client,
    Uri uri,
    String method,
    Map<String, String> headers,
    String? body,
    String format,
  ) async {
    if (method != 'GET' && method != 'POST') {
      return ToolExecutionResult.error('Error: Unsupported method: $method');
    }
    var currentUri = uri;
    var currentMethod = method;
    var redirects = 0;
    late HttpClientResponse response;
    while (true) {
      final blocked = blockedReason(currentUri);
      if (blocked != null) {
        return ToolExecutionResult.error('Error: Blocked: $blocked ($uri)');
      }
      final request = await client.openUrl(currentMethod, currentUri);
      request.followRedirects = false;
      headers.forEach(request.headers.add);
      if (currentMethod == 'POST' && body != null) {
        final bytes = utf8.encode(body);
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      response = await request.close();
      if (!const [301, 302, 303, 307, 308].contains(response.statusCode)) break;
      final location = response.headers.value('location');
      // 要返回的响应必须留给下面的读取器；单订阅流排空后不能再次读取。
      if (location == null || redirects >= _maxRedirects) break;
      final nextUri = currentUri.resolve(location);
      if (nextUri.origin != currentUri.origin) {
        return ToolExecutionResult.success(
          'Status: ${response.statusCode}\nRedirect: $nextUri\n\n'
          'The server redirected to a different origin. The redirect '
          'was not followed; call web_fetch again with the URL above '
          'if you want its content.',
        );
      }
      await response.drain<void>();
      currentUri = nextUri;
      redirects++;
      if (response.statusCode != 307 && response.statusCode != 308) {
        currentMethod = 'GET';
      }
    }

    final bodyBytes = BytesBuilder(copy: false);
    var overLimit = false;
    await for (final chunk in response) {
      final remaining = _maxResponseBytes - bodyBytes.length;
      if (chunk.length > remaining) {
        bodyBytes.add(chunk.sublist(0, remaining));
        overLimit = true;
        break;
      }
      bodyBytes.add(chunk);
    }
    final knownTotal = response.contentLength;
    final tooLarge = overLimit || knownTotal > _maxResponseBytes;
    final contentType = response.headers.value('content-type') ?? '';
    final raw = _decodeBody(
      bodyBytes.takeBytes(),
      contentType,
      truncated: tooLarge,
    );
    final looksLikeHtml =
        contentType.toLowerCase().contains('text/html') || _hasHtmlTags(raw);
    final output = format == 'markdown' && looksLikeHtml
        ? htmlToMarkdown(raw, pageUrl: currentUri)
        : raw;
    final result = StringBuffer()
      ..writeln('Status: ${response.statusCode}')
      ..writeln('Reason: ${response.reasonPhrase}')
      ..writeln(
        'Content-Type: ${contentType.isEmpty ? '(unknown)' : contentType}',
      )
      ..writeln()
      ..write(output);
    if (tooLarge) {
      result.writeln(
        '\n\n[Response truncated: limit ${_maxResponseBytes ~/ 1024}KB]',
      );
      result.write(
        'Use a more specific URL or API endpoint to retrieve missing content.',
      );
    }
    return ToolExecutionResult.success(result.toString());
  }

  static String _decodeBody(
    List<int> bytes,
    String contentType, {
    required bool truncated,
  }) {
    final charset = contentType.isEmpty
        ? null
        : ContentType.parse(contentType).charset;
    final encoding = charset == null ? null : Encoding.getByName(charset);
    if (charset != null && encoding == null) {
      throw UnsupportedError('Unsupported response charset: $charset');
    }
    if (encoding != null && encoding != utf8) return encoding.decode(bytes);
    // UTF-8 是常见页面/API 的默认编码。字节截断只去掉末尾不完整的码点，
    // 中间的非法数据仍明确报错，不能用 allowMalformed 静默替换整份内容。
    var end = bytes.length;
    if (truncated && end > 0) {
      var start = end - 1;
      while (start > 0 && bytes[start] & 0xC0 == 0x80) {
        start--;
      }
      final first = bytes[start];
      final expected = first & 0xE0 == 0xC0
          ? 2
          : first & 0xF0 == 0xE0
          ? 3
          : first & 0xF8 == 0xF0
          ? 4
          : 1;
      if (end - start < expected) end = start;
    }
    final selected = bytes.sublist(0, end);
    try {
      return utf8.decode(selected);
    } on FormatException {
      if (encoding != null || contentType.toLowerCase().contains('json')) {
        rethrow;
      }
      return latin1.decode(bytes);
    }
  }

  /// 简单试探：检测文本是否包含 HTML 标签。
  static bool _hasHtmlTags(String text) {
    final upper = text.length > 2000 ? text.substring(0, 2000) : text;
    return RegExp(
      r'<\s*(html|head|body|div|p|h[1-6]|span|a\s|table)',
      caseSensitive: false,
    ).hasMatch(upper);
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
  /// 绕过——fake-ip 代理下由代理层缓解；直连场景由 POST / body / 自定义
  /// headers 不吃持久 allow 规则（PermissionService）、跨 origin 跳转不跟随
  /// 兜底。
  @visibleForTesting
  static String? blockedReason(Uri uri) {
    // 末尾的点是合法的 FQDN 写法（`localhost.` 同样解析到本机）
    var host = uri.host.toLowerCase();
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return 'empty host';
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return 'localhost / .local hosts are not allowed';
    }
    // 整数 / 十六进制 / 八进制（`0177.0.0.1`）/ 省略段（`127.1`）等非规范
    // IPv4 写法：系统解析器（inet_aton）当作 IP，而 tryParse 要么不认、要么
    // 按十进制读成另一个地址。只接受规范的点分十进制，其余一律拒绝。
    final labels = host.split('.');
    if (labels.every(RegExp(r'^(0x[0-9a-f]*|\d+)$').hasMatch) &&
        (labels.length != 4 ||
            !labels.every(RegExp(r'^(0|[1-9]\d{0,2})$').hasMatch))) {
      return 'non-canonical numeric IP address $host is not allowed';
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
    // IPv4 映射 / 兼容地址（::ffff:a.b.c.d、::a.b.c.d）直达内嵌的 IPv4，
    // 按内嵌地址判定
    final v4Embedded =
        bytes.take(10).every((b) => b == 0) &&
        ((bytes[10] == 0xFF && bytes[11] == 0xFF) ||
            (bytes[10] == 0 && bytes[11] == 0));
    if (v4Embedded) {
      return _isPrivateOrReserved(
        InternetAddress.fromRawAddress(
          bytes.sublist(12),
          type: InternetAddressType.IPv4,
        ),
      );
    }
    final isZero = bytes.every((b) => b == 0);
    final isLoopback = bytes[15] == 1 && bytes.take(15).every((b) => b == 0);
    if (isZero || isLoopback) return true; // :: 与 ::1
    if (bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80) {
      return true; // fe80::/10 link-local
    }
    if ((bytes[0] & 0xFE) == 0xFC) return true; // fc00::/7 unique local
    return false;
  }
}
