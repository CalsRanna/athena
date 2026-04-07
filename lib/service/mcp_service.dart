import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/entity/server_entity.dart';

/// MCP Service 负责与 MCP 服务器的连接和通信
class MCPService {
  final Map<int, Process> _processes = {};
  final Map<int, StreamIterator<String>> _stdoutIterators = {};

  /// 启动 MCP 服务器进程并获取工具列表
  Future<Map<String, dynamic>> connectAndGetTools(ServerEntity server) async {
    try {
      // 启动进程
      var process = await Process.start(
        server.command,
        server.arguments,
        environment: server.environmentVariables,
      );

      _processes[server.id!] = process;
      var stdoutIterator = StreamIterator<String>(
        process.stdout.transform(utf8.decoder).transform(LineSplitter()),
      );
      _stdoutIterators[server.id!] = stdoutIterator;

      // 发送 initialize 请求
      var initRequest = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'athena', 'version': '1.0.0'},
        },
      };

      process.stdin.writeln(jsonEncode(initRequest));
      await process.stdin.flush();

      // 等待响应(超时5秒)
      var response = await _readResponse(
        stdoutIterator,
        (response) => response['id'] == 1,
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () => {'error': 'Connection timeout'},
      );
      if (response['error'] != null) {
        return {'error': response['error']};
      }

      // 发送 initialized 通知
      var initializedNotification = {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      };
      process.stdin.writeln(jsonEncode(initializedNotification));
      await process.stdin.flush();

      // 发送 tools/list 请求
      var toolsRequest = {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'};

      process.stdin.writeln(jsonEncode(toolsRequest));
      await process.stdin.flush();

      var toolsResponse = await _readResponse(
        stdoutIterator,
        (response) => response['id'] == 2,
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () => {'error': 'Tools list timeout'},
      );
      if (toolsResponse['error'] != null) {
        return {'error': toolsResponse['error']};
      }

      return {
        'serverInfo': response['result']?['serverInfo'],
        'tools': toolsResponse['result']?['tools'] ?? [],
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 断开服务器连接
  Future<void> disconnect(int serverId) async {
    await _stdoutIterators[serverId]?.cancel();
    _stdoutIterators.remove(serverId);

    // 杀死进程
    _processes[serverId]?.kill();
    _processes.remove(serverId);
  }

  /// 断开所有连接
  Future<void> disconnectAll() async {
    for (var serverId in _processes.keys.toList()) {
      await disconnect(serverId);
    }
  }

  void dispose() {
    disconnectAll();
  }

  Future<Map<String, dynamic>> _readResponse(
    StreamIterator<String> iterator,
    bool Function(Map<String, dynamic> response) predicate,
  ) async {
    while (await iterator.moveNext()) {
      var line = iterator.current.trim();
      if (line.isEmpty) continue;
      try {
        var decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        var response = Map<String, dynamic>.from(decoded);
        if (predicate(response)) {
          return response;
        }
      } catch (_) {
        // Ignore invalid JSON lines and continue waiting for the expected response.
      }
    }
    return {'error': 'Connection closed'};
  }
}
