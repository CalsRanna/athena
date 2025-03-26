import 'package:athena/schema/isar.dart';
import 'package:athena/schema/server.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server.g.dart';

@riverpod
class EnabledServersNotifier extends _$EnabledServersNotifier {
  @override
  Future<List<Server>> build() async {
    var servers = await ref.watch(serversNotifierProvider.future);
    return servers.where((server) => server.enabled).toList();
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
class ServersNotifier extends _$ServersNotifier {
  @override
  Future<List<Server>> build() async {
    return isar.servers.where().findAll();
  }
}
