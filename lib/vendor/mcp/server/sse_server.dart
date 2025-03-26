import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';

class McpSseServer {
  final Map<String, McpTool> _tools = {};
  final Map<String, Function(Map<String, dynamic>?)> _functions = {};
  final _clients = <HttpRequest>{};

  Future<void> broadcastNotification(
    McpJsonRpcNotification notification,
  ) async {
    final message = 'data: ${jsonEncode(notification.toJson())}\n\n';
    for (final client in _clients) {
      try {
        client.response.write(message);
        await client.response.flush();
      } catch (e) {
        _clients.remove(client);
      }
    }
  }

  void registerTool(McpTool tool, Function(Map<String, dynamic>?) caller) {
    _tools[tool.name] = tool;
    _functions[tool.name] = caller;
  }

  Future<void> start({int port = 8080}) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    LoggerUtil.logger.d('Server started on port $port');

    await for (final request in server) {
      if (request.uri.path == '/sse') {
        _handleSseConnection(request);
      } else if (request.method == 'POST') {
        _handleJsonRpcRequest(request);
      } else {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..write('Method not allowed')
          ..close();
      }
    }
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

  Future<void> _handleJsonRpcRequest(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final json = jsonDecode(content) as Map<String, dynamic>;

      if (json.containsKey('method')) {
        if (json['id'] == null) {
          final notification = McpJsonRpcNotification.fromJson(json);
          await _handleNotification(notification, request);
        } else {
          final rpcRequest = McpJsonRpcRequest.fromJson(json);
          await _handleRequest(rpcRequest, request);
        }
      }
    } catch (e, stack) {
      LoggerUtil.logger.e('Error handling request: $e\n$stack');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Invalid request')
        ..close();
    }
  }

  Future<Map<String, dynamic>> _handleListTools(
    McpJsonRpcRequest request,
  ) async {
    return {
      'tools': _tools.values.map((tool) => tool.toJson()).toList(),
    };
  }

  Future<void> _handleNotification(
    McpJsonRpcNotification notification,
    HttpRequest request,
  ) async {
    LoggerUtil.logger.d('Received notification: ${notification.method}');
    request.response
      ..statusCode = HttpStatus.ok
      ..write('Notification received')
      ..close();
  }

  Future<String> _handlePing(McpJsonRpcRequest request) async {
    return 'pong';
  }

  Future<void> _handleRequest(
    McpJsonRpcRequest request,
    HttpRequest httpRequest,
  ) async {
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

      final response = McpJsonRpcResponse(
        id: request.id,
        jsonrpc: '2.0',
        result: result,
        error: error,
      );

      httpRequest.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response.toJson()))
        ..close();
    } catch (e, stack) {
      LoggerUtil.logger.e('Error handling request: $e\n$stack');
      final response = McpJsonRpcResponse(
        id: request.id,
        jsonrpc: '2.0',
        error: {'code': -32603, 'message': 'Internal error'},
      );
      httpRequest.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response.toJson()))
        ..close();
    }
  }

  void _handleSseConnection(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.set('Cache-Control', 'no-cache')
      ..headers.set('Connection', 'keep-alive');

    // Send endpoint information
    request.response.write('event: endpoint\ndata: /jsonrpc\n\n');
    request.response.flush();

    _clients.add(request);
    request.response.done.then((_) => _clients.remove(request));
  }
}
