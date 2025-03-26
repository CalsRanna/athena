import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';

class McpStdioServer {
  final Map<String, McpTool> _tools = {};
  final Map<String, Function(Map<String, dynamic>?)> _functions = {};
  final StreamController<String> _outputController = StreamController();

  void registerTool(McpTool tool, Function(Map<String, dynamic>?) caller) {
    _tools[tool.name] = tool;
    _functions[tool.name] = caller;
  }

  Future<void> start() async {
    LoggerUtil.logger.d('Starting stdio server...');

    // 监听标准输入
    stdin.transform(utf8.decoder).transform(LineSplitter()).listen(
      (line) async {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          await _handleInput(json);
        } catch (e, stack) {
          LoggerUtil.logger.e('Error processing input: $e\n$stack');
          _sendErrorResponse('Invalid JSON input');
        }
      },
      onError: (e) => LoggerUtil.logger.e('Input error: $e'),
    );

    // 监听输出流
    _outputController.stream.listen(
      (line) => stdout.writeln(line),
      onError: (e) => LoggerUtil.logger.e('Output error: $e'),
    );
  }

  Future<dynamic> _handleCallTool(McpJsonRpcRequest request) async {
    final toolName = request.params?['name'] as String?;
    final arguments = request.params?['arguments'] as Map<String, dynamic>?;

    if (toolName == null || !_tools.containsKey(toolName)) {
      throw Exception('Tool not found: $toolName');
    }

    return await _functions[toolName]!.call(arguments ?? {});
  }

  Future<Map<String, dynamic>> _handleInitialize(
    McpJsonRpcRequest request,
  ) async {
    return {
      'capabilities': {
        'textDocumentSync': 1,
        'completionProvider': {'resolveProvider': false},
      }
    };
  }

  Future<void> _handleInput(Map<String, dynamic> json) async {
    if (json.containsKey('method')) {
      if (json['id'] == null) {
        final notification = McpJsonRpcNotification.fromJson(json);
        await _handleNotification(notification);
      } else {
        final request = McpJsonRpcRequest.fromJson(json);
        await _handleRequest(request);
      }
    }
  }

  Future<Map<String, dynamic>> _handleListTools(
    McpJsonRpcRequest request,
  ) async {
    return {
      'tools': _tools.values.map((tool) => tool.toJson()).toList(),
    };
  }

  Future<void> _handleNotification(McpJsonRpcNotification notification) async {
    LoggerUtil.logger.d('Received notification: ${notification.method}');
  }

  Future<String> _handlePing(McpJsonRpcRequest request) async {
    return 'pong';
  }

  Future<void> _handleRequest(McpJsonRpcRequest request) async {
    LoggerUtil.logger.d('Received request: ${request.method}');

    try {
      dynamic result;
      dynamic error;

      switch (request.method) {
        case 'initialize':
          result = await _handleInitialize(request);
          break;
        case 'tools/list':
          result = await _handleListTools(request);
          break;
        case 'tools/call':
          result = await _handleCallTool(request);
          break;
        case 'ping':
          result = await _handlePing(request);
          break;
        default:
          error = {'code': -32601, 'message': 'Method not found'};
      }

      _sendResponse(
        McpJsonRpcResponse(
          id: request.id,
          jsonrpc: '2.0',
          result: result,
          error: error,
        ),
      );
    } catch (e, stack) {
      LoggerUtil.logger.e('Error handling request: $e\n$stack');
      _sendErrorResponse('Internal server error', request.id);
    }
  }

  void _sendErrorResponse(String message, [String? id]) {
    _sendResponse(
      McpJsonRpcResponse(
        id: id ?? '',
        jsonrpc: '2.0',
        error: {'code': -32603, 'message': message},
      ),
    );
  }

  void _sendResponse(McpJsonRpcResponse response) {
    _outputController.add(jsonEncode(response.toJson()));
  }
}
