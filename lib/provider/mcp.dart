import 'dart:convert';

import 'package:athena/model/tool_call.dart';
import 'package:athena/provider/server.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/logger_util.dart';
import 'package:athena/util/mcp_client_extension.dart';
import 'package:dart_mcp/client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mcp.g.dart';

@riverpod
class McpToolsNotifier extends _$McpToolsNotifier {
  @override
  Future<Map<String, List<Tool>>> build() async {
    var connections = await ref.read(mcpConnectionsNotifierProvider.future);
    var tools = <String, List<Tool>>{};
    for (var serverName in connections.keys) {
      var connection = connections[serverName];
      if (connection == null) continue;
      var result = await connection.listTools();
      tools[serverName] = result.tools;
    }
    return tools;
  }

  Future<ServerConnection?> getConnectionByToolCall(ToolCall toolCall) async {
    var tools = await future;
    var serverName = tools.entries
        .firstWhere((entry) =>
            entry.value.any((tool) => tool.name == toolCall.name.toString()))
        .key;
    var connections = await ref.read(mcpConnectionsNotifierProvider.future);
    return connections[serverName];
  }
}

@riverpod
class McpConnectionsNotifier extends _$McpConnectionsNotifier {
  @override
  Future<Map<String, ServerConnection>> build() async {
    // Use `read` not `watch` to manually controller the server toggle
    var servers = await ref.read(enabledServersNotifierProvider.future);
    var connections = <String, ServerConnection>{};
    for (var server in servers) {
      var implementation = Implementation(name: server.name, version: '1.0.0');
      var client = MCPClient(implementation);
      var connection = await client.connectStdioServerWithEnvironment(
        server.command,
        server.arguments.split(' '),
        environment: Map<String, String>.from(jsonDecode(server.environments)),
      );
      connection.onLog.listen((event) {
        LoggerUtil.logger.d(event);
      });

      connection.done.then((_) {
        LoggerUtil.logger.w('Connection to ${server.name} has been closed.');
        ref
            .read(mcpConnectionsNotifierProvider.notifier)
            .removeServer(server.name);
      });

      await connection.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: implementation,
        ),
      );
      connection.notifyInitialized();
      connections[server.name] = connection;
    }
    return connections;
  }

  Future<void> toggleServer(Server server) async {
    if (server.enabled) {
      var implementation = Implementation(name: server.name, version: '1.0.0');
      var client = MCPClient(implementation);
      var connection = await client.connectStdioServerWithEnvironment(
        server.command,
        server.arguments.split(' '),
        environment: Map<String, String>.from(jsonDecode(server.environments)),
      );
      connection.onLog.listen((event) {
        LoggerUtil.logger.d(event);
      });

      connection.done.then((_) {
        LoggerUtil.logger.w('Connection to ${server.name} has been closed.');
        ref
            .read(mcpConnectionsNotifierProvider.notifier)
            .removeServer(server.name);
      });

      await connection.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: implementation,
        ),
      );
      connection.notifyInitialized();
      var connections = await future;
      connections[server.name] = connection;
      state = AsyncData(Map.from(connections));
    } else {
      var connections = await future;
      var connection = connections[server.name];
      connection?.shutdown();
      connections.remove(server.name);
      state = AsyncData(Map.from(connections));
    }
  }

  Future<void> removeServer(String serverName) async {
    var connections = await future;
    if (connections.containsKey(serverName)) {
      connections.remove(serverName);
      state = AsyncData(Map.from(connections));
    }
  }
}
