import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/method.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';
import 'package:http/http.dart';

class McpSseClient {
  final McpServerOption option;
  String? _endpoint;
  final _requests = <String, Completer<McpJsonRpcResponse>>{};
  late final StreamSubscription _subscription;

  McpSseClient({required this.option});

  Future<McpJsonRpcResponse> callTool(
    McpTool tool, {
    Map<String, dynamic>? arguments,
  }) async {
    final message = McpJsonRpcRequest(
      method: McpMethod.callTool.value,
      params: {'name': tool.name, 'arguments': arguments},
    );
    return _request(message);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
  }

  Future<void> initialize() async {
    await _setup();
    await _initialize();
    await _ping();
  }

  Future<List<McpTool>> listTools() async {
    final message = McpJsonRpcRequest(method: McpMethod.listTools.value);
    var response = await _request(message);
    var result = response.result['tools'] as List;
    return result
        .map((item) => McpTool.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _handleMessage(McpJsonRpcResponse message) {
    if (_requests.containsKey(message.id)) {
      final completer = _requests.remove(message.id);
      completer?.complete(message);
    }
  }

  Future<void> _initialize() async {
    var params = {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'roots': {'listChanged': true},
        'sampling': {},
      },
      'clientInfo': {'name': 'McpStdioClient', 'version': '1.0.0'},
    };
    final initializeRequest = McpJsonRpcRequest(
      method: McpMethod.initialize.value,
      params: params,
    );
    try {
      await _request(initializeRequest);
      final notification = McpJsonRpcNotification(
        method: McpMethod.notificationsInitialized.value,
      );
      await _notify(notification);
    } catch (e) {
      LoggerUtil.logger.e(e);
      rethrow;
    }
  }

  Future<void> _notify(McpJsonRpcNotification notification) async {
    LoggerUtil.logger.d('RpcJsonNotification: $notification');
    await _writeRequest(notification.toJson());
  }

  void _onData(String line) {
    if (line.startsWith('event: endpoint')) {
      return;
    }
    if (line.startsWith('data: ')) {
      final data = line.substring(6);
      if (_endpoint == null) {
        final baseUrl = Uri.parse(option.command).replace(path: '').toString();
        _endpoint = data.startsWith("http") ? data : baseUrl + data;
        LoggerUtil.logger.d('JsonRpcResponse: $_endpoint');
        return;
      }
      try {
        final jsonData = jsonDecode(data);
        final message = McpJsonRpcResponse.fromJson(jsonData);
        _handleMessage(message);
      } catch (e, stack) {
        LoggerUtil.logger.e('Unknown error: $e\n$stack');
      }
    }
  }

  Future<McpJsonRpcResponse> _ping() async {
    final message = McpJsonRpcRequest(method: McpMethod.ping.value);
    return _request(message);
  }

  Future<McpJsonRpcResponse> _request(McpJsonRpcRequest message) async {
    final completer = Completer<McpJsonRpcResponse>();
    _requests[message.id] = completer;

    try {
      await _writeRequest(message.toJson());
      return completer.future;
      // return await completer.future.timeout(
      //   const Duration(seconds: 30),
      //   onTimeout: () {
      //     _requests.remove(message.id);
      //     throw TimeoutException('请求超时: ${message.id}');
      //   },
      // );
    } catch (e) {
      _requests.remove(message.id);
      rethrow;
    }
  }

  Future<void> _setup() async {
    try {
      final client = HttpClient();
      var uri = Uri.parse(option.command);
      LoggerUtil.logger.d('Start: ${option.command}');
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');
      request.headers.set('Connection', 'keep-alive');
      final response = await request.close();
      if (response.statusCode != 200) {
        LoggerUtil.logger.d('Start error: ${response.statusCode}');
        throw Exception('Start error: ${response.statusCode}');
      }

      const lineSplitter = LineSplitter();
      var stream = response.transform(utf8.decoder).transform(lineSplitter);
      _subscription = stream.listen(
        _onData,
        onError: (error) => LoggerUtil.logger.e(error),
      );
    } catch (e, stack) {
      LoggerUtil.logger.d('SSE 连接失败: $e\n$stack');
      rethrow;
    }
  }

  Future<void> _writeRequest(Map<String, dynamic> data) async {
    if (_endpoint == null) {
      LoggerUtil.logger.e('Endpoint is not set');
      throw StateError('Endpoint is not set');
    }
    try {
      var uri = Uri.parse(_endpoint!);
      var headers = {'Content-Type': 'application/json'};
      await post(uri, body: data, headers: headers);
    } catch (e) {
      LoggerUtil.logger.e('Http error: $e');
      rethrow;
    }
  }
}
