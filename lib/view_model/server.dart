import 'package:athena/provider/server.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_dart/mcp_dart.dart';

class ServerViewModel extends ViewModel {
  final WidgetRef ref;

  ServerViewModel(this.ref);

  Future<void> destroyServer(Server server) async {
    await isar.writeTxn(() async {
      await isar.servers.delete(server.id);
    });
    ref.invalidate(serversNotifierProvider);
  }

  Future<void> storeServer(Server server) async {
    await isar.writeTxn(() async {
      await isar.servers.put(server);
    });
    ref.invalidate(serversNotifierProvider);
  }

  Future<void> updateServer(Server server) async {
    await isar.writeTxn(() async {
      await isar.servers.put(server);
    });
    ref.invalidate(serversNotifierProvider);
    AthenaDialog.message('Server updated');
  }

  Future<List<McpTool>> getMcpTools(List<Server> servers) async {
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
