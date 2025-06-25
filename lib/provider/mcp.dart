import 'package:athena/provider/server.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';
import 'package:dart_mcp/client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mcp.g.dart';

@riverpod
class McpToolsNotifier extends _$McpToolsNotifier {
  @override
  Future<List<Tool>> build() async {
    var connections = await ref.read(mcpConnectionsNotifierProvider.future);
    var tools = <Tool>[];
    for (var connection in connections.values) {
      var result = await connection.listTools();
      tools.addAll(result.tools);
    }
    return tools;
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
      var connection = await client.connectStdioServer(
        server.command,
        server.arguments.split(' '),
      );
      connection.onLog.listen((event) {
        LoggerUtil.logger.d(event);
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
      var connection = await client.connectStdioServer(
        server.command,
        server.arguments.split(' '),
      );
      connection.onLog.listen((event) {
        LoggerUtil.logger.d(event);
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
}
