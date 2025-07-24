import 'dart:convert';
import 'dart:io';

import 'package:athena/provider/mcp.dart';
import 'package:athena/provider/server.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/logger_util.dart';
import 'package:athena/util/mcp_client_extension.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:dart_mcp/client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerViewModel extends ViewModel {
  final WidgetRef ref;

  ServerViewModel(this.ref);

  Future<void> destroyServer(Server server) async {
    await isar.writeTxn(() async {
      await isar.servers.delete(server.id);
    });
    ref.invalidate(serversNotifierProvider);
  }

  Future<void> emptyServers() async {
    await isar.writeTxn(() async {
      await isar.servers.clear();
    });
    ref.invalidate(serversNotifierProvider);
  }

  Future<String> refreshTools(BuildContext context, Server server) async {
    AthenaDialog.loading();
    var implementation = Implementation(name: server.name, version: '1.0.0');
    var client = MCPClient(implementation);
    var connection = await client.connectStdioServerWithEnvironment(
      server.command,
      server.arguments.split(' '),
      environment: _mergeDefaultPath(server),
    );
    connection.onLog.listen((event) {
      LoggerUtil.logger.d(event);
    });

    connection.done.then((_) {
      LoggerUtil.logger.d('Connection to ${server.name} has been closed.');
    });

    await connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: implementation,
      ),
    );
    connection.notifyInitialized();
    var result = await connection.listTools();
    await connection.shutdown();
    var briefTools = result.tools.map((tool) {
      return {
        'name': tool.name,
        'description': tool.description,
      };
    }).toList();
    var toolString = jsonEncode(briefTools);
    var updatedServer = server.copyWith(tools: toolString);
    await isar.writeTxn(() async {
      await isar.servers.put(updatedServer);
    });
    AthenaDialog.dismiss();
    return toolString;
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
    ref.read(mcpConnectionsNotifierProvider.notifier).toggleServer(server);
    AthenaDialog.message('Server updated');
  }

  Map<String, String> _mergeDefaultPath(Server server) {
    var originalPath = Platform.environment['PATH'] ?? '';
    var presetPaths = [
      '/opt/homebrew/bin',
      '/opt/homebrew/sbin',
      '/usr/local/bin',
      '/System/Cryptexes/App/usr/bin',
      '/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin',
      '/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin',
      '/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin',
      '/Library/Apple/usr/bin'
    ];
    Map<String, String> environment = {};
    if (server.environments.isNotEmpty) {
      environment = Map<String, String>.from(jsonDecode(server.environments));
    }
    environment['PATH'] = '${presetPaths.join(':')}:$originalPath';
    return environment;
  }
}
