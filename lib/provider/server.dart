import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:isar/isar.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server.g.dart';

@riverpod
class ServersNotifier extends _$ServersNotifier {
  @override
  Future<List<Server>> build() async {
    return isar.servers.where().findAll();
  }
}

@riverpod
class ServerNotifier extends _$ServerNotifier {
  @override
  Future<Server> build(int id) async {
    var builder = isar.servers.filter().idEqualTo(id);
    var server = await builder.findFirst();
    if (server == null) throw Exception('Server not found');
    return server;
  }
}

@riverpod
class ToolsNotifier extends _$ToolsNotifier {
  @override
  Future<List<McpTool>> build() async {
    var servers = await ref.watch(serversNotifierProvider.future);
    List<McpTool> combinedTools = [];
    for (var server in servers) {
      var json = {
        'command': server.command,
        'args': server.arguments.split(' '),
      };
      var option = McpServerOption.fromJson(json);
      var client = McpStdioClient(option: option);
      await client.initialize();
      var tools = await client.listTools();
      combinedTools.addAll(tools);
      client.dispose();
    }
    return combinedTools;
  }
}
