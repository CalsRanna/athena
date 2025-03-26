import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/method.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';
import 'package:athena/vendor/mcp/util/process_util.dart';

class McpStdioClient {
  final McpServerOption option;
  late final Process _process;
  final _requests = <String, Completer<McpJsonRpcResponse>>{};

  McpStdioClient({required this.option});

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
    ProcessUtil.kill(_process);
  }

  Future<void> initialize() async {
    await _setup();
    await _initialize();
  }

  Future<List<McpTool>> listTools() async {
    final message = McpJsonRpcRequest(method: McpMethod.listTools.value);
    var response = await _request(message);
    var result = response.result['tools'] as List;
    return result
        .map((item) => McpTool.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> notify(McpJsonRpcNotification notification) async {
    LoggerUtil.logger.d('RpcJsonNotification: $notification');
    await ProcessUtil.writeNotification(_process, notification);
  }

  Future<McpJsonRpcResponse> _request(McpJsonRpcRequest request) async {
    LoggerUtil.logger.d('RpcJsonRequest: $request');
    final completer = Completer<McpJsonRpcResponse>();
    _requests[request.id] = completer;
    try {
      await ProcessUtil.writeRequest(_process, request);
      return completer.future;
      // return await completer.future.timeout(
      //   const Duration(seconds: 30),
      //   onTimeout: () {
      //     _requests.remove(request.id);
      //     throw TimeoutException('Request timed out: ${request.id}');
      //   },
      // );
    } catch (e) {
      _requests.remove(request.id);
      rethrow;
    }
  }

  Future<McpJsonRpcResponse> ping() async {
    final message = McpJsonRpcRequest(method: McpMethod.ping.value);
    return _request(message);
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
      await notify(notification);
    } catch (e) {
      LoggerUtil.logger.e(e);
      rethrow;
    }
  }

  Future<void> _setup() async {
    try {
      _process = await ProcessUtil.start(option);
      var command = [option.command, ...option.args];
      LoggerUtil.logger.d('Start: ${command.join(" ")}');
      ProcessUtil.listenStdout(_process, (text) {
        try {
          final response = McpJsonRpcResponse.fromJson(jsonDecode(text));
          LoggerUtil.logger.d('JsonRpcResponse: $response');
          final request = _requests.remove(response.id);
          request?.complete(response);
        } catch (e, stack) {
          LoggerUtil.logger.e('Unknown error: $e\n$stack');
        }
      });
      ProcessUtil.listenStderr(_process, (error) {
        LoggerUtil.logger.e('Stderr: $error');
      });
    } catch (e, stack) {
      LoggerUtil.logger.d('启动进程失败: $e\n$stack');
      rethrow;
    }
  }
}
