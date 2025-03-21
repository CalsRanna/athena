import 'package:athena/provider/server.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:athena/widget/dialog.dart';
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
}
