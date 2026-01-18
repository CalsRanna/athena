import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena/entity/server_entity.dart';

/// MCP Service 负责与 MCP 服务器的连接和通信
class MCPService {
  final Map<int, Process> _processes = {};
  final Map<int, StreamSubscription> _subscriptions = {};

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

      // 读取响应
      var completer = Completer<Map<String, dynamic>>();
      var subscription = process.stdout
          .transform(utf8.decoder)
          .transform(LineSplitter())
          .listen((line) {
            if (line.trim().isEmpty) return;
            try {
              var response = jsonDecode(line);
              if (!completer.isCompleted) {
                completer.complete(response);
              }
            } catch (e) {
              // Ignore invalid JSON
            }
          });

      _subscriptions[server.id!] = subscription;

      // 等待响应(超时5秒)
      var response = await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => {'error': 'Connection timeout'},
      );

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

      // 读取工具列表响应
      var toolsCompleter = Completer<Map<String, dynamic>>();
      subscription = process.stdout
          .transform(utf8.decoder)
          .transform(LineSplitter())
          .listen((line) {
            if (line.trim().isEmpty) return;
            try {
              var response = jsonDecode(line);
              if (response['id'] == 2 && !toolsCompleter.isCompleted) {
                toolsCompleter.complete(response);
              }
            } catch (e) {
              // Ignore invalid JSON
            }
          });

      var toolsResponse = await toolsCompleter.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => {'error': 'Tools list timeout'},
      );

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
    // 取消订阅
    await _subscriptions[serverId]?.cancel();
    _subscriptions.remove(serverId);

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
}
