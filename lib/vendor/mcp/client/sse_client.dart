import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';

class McpSseClient {
  final McpServerOption option;
  final _pendingRequests = <String, Completer<McpJsonRpcResponse>>{};
  StreamSubscription? _sseSubscription;

  String? _messageEndpoint;
  McpSseClient({required this.option});

  Future<void> dispose() async {
    await _sseSubscription?.cancel();
  }

  Future<void> initialize() async {
    try {
      LoggerUtil.logger.d('开始 SSE 连接: ${option.command}');

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(option.command));
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      request.headers.set('Connection', 'keep-alive');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('SSE 连接失败: ${response.statusCode}');
      }

      _sseSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          if (line.startsWith('event: endpoint')) {
            return;
          }
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (_messageEndpoint == null) {
              final baseUrl =
                  Uri.parse(option.command).replace(path: '').toString();
              _messageEndpoint =
                  data.startsWith("http") ? data : baseUrl + data;
              LoggerUtil.logger.d('收到消息端点: $_messageEndpoint');
            } else {
              try {
                final jsonData = jsonDecode(data);
                final message = McpJsonRpcResponse.fromJson(jsonData);
                _handleMessage(message);
              } catch (e, stack) {
                LoggerUtil.logger.d('解析服务器消息失败: $e\n$stack');
              }
            }
          }
        },
        onError: (error) {
          LoggerUtil.logger.d('SSE 连接错误: $error');
        },
        onDone: () {
          LoggerUtil.logger.d('SSE 连接已关闭');
        },
      );
    } catch (e, stack) {
      LoggerUtil.logger.d('SSE 连接失败: $e\n$stack');
      rethrow;
    }
  }

  Future<McpJsonRpcResponse> request(McpJsonRpcRequest message) async {
    final completer = Completer<McpJsonRpcResponse>();
    _pendingRequests[message.id] = completer;

    try {
      await _sendHttpPost(message.toJson());
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingRequests.remove(message.id);
          throw TimeoutException('请求超时: ${message.id}');
        },
      );
    } catch (e) {
      _pendingRequests.remove(message.id);
      rethrow;
    }
  }

  Future<McpJsonRpcResponse> sendInitialize() async {
    final initMessage = McpJsonRpcRequest(
      method: 'initialize',
      params: {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'roots': {'listChanged': true},
          'sampling': {},
        },
        'clientInfo': {'name': 'DartMCPClient', 'version': '1.0.0'},
      },
    );

    LoggerUtil.logger.d('初始化请求: ${jsonEncode(initMessage.toString())}');

    final initResponse = await request(initMessage);
    LoggerUtil.logger.d('初始化请求响应: $initResponse');

    final notifyMessage = McpJsonRpcNotification(
      method: 'initialized',
      params: {},
    );

    await _sendHttpPost(notifyMessage.toJson());
    return initResponse;
  }

  Future<McpJsonRpcResponse> sendPing() async {
    final message = McpJsonRpcRequest(method: 'ping');
    return request(message);
  }

  Future<McpJsonRpcResponse> sendToolCall({
    required String name,
    required Map<String, dynamic> arguments,
    String? id,
  }) async {
    final message = McpJsonRpcRequest(
      method: 'tools/call',
      params: {
        'name': name,
        'arguments': arguments,
        '_meta': {'progressToken': 0},
      },
    );

    return request(message);
  }

  Future<McpJsonRpcResponse> sendToolList() async {
    final message = McpJsonRpcRequest(method: 'tools/list');
    return request(message);
  }

  void _handleMessage(McpJsonRpcResponse message) {
    if (_pendingRequests.containsKey(message.id)) {
      final completer = _pendingRequests.remove(message.id);
      completer?.complete(message);
    }
  }

  Future<void> _sendHttpPost(Map<String, dynamic> data) async {
    // if (_messageEndpoint == null) {
    //   throw StateError('消息端点尚未初始化 ${jsonEncode(data)}');
    // }

    // await _writeLock.synchronized(() async {
    //   try {
    //     await Dio().post(
    //       _messageEndpoint!,
    //       data: jsonEncode(data),
    //       options: Options(headers: {'Content-Type': 'application/json'}),
    //     );
    //   } catch (e) {
    //     LoggerUtil.logger.d('发送 HTTP POST 失败: $e');
    //     rethrow;
    //   }
    // });
  }
}
