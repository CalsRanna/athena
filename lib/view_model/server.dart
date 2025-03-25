import 'package:athena/provider/server.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/vendor/mcp/util/process_util.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServerViewModel extends ViewModel {
  final WidgetRef ref;

  ServerViewModel(this.ref);

  Future<void> emptyServers() async {
    await isar.writeTxn(() async {
      await isar.servers.clear();
    });
    ref.invalidate(serversNotifierProvider);
  }

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

  Future<String> debugCommand(String command) async {
    try {
      var output = 'which $command: ';
      var result = await ProcessUtil.run('which $command');
      var stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty) output += '\n$stdout';
      var stderr = result.stderr.toString().trim();
      if (stderr.isNotEmpty) output += '\n$stderr';
      output += '\n\n$command --version: ';
      result = await ProcessUtil.run('$command --version');
      stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty) output += '\n$stdout';
      stderr = result.stderr.toString().trim();
      if (stderr.isNotEmpty) output += '\n$stderr';
      return output;
    } catch (error) {
      return error.toString();
    }
  }
}
