import 'package:athena/entity/server_entity.dart';
import 'package:athena/repository/server_repository.dart';
import 'package:athena/service/mcp_service.dart';
import 'package:signals/signals.dart';

class ServerViewModel {
  // ViewModel 内部直接持有 Repository
  final ServerRepository _serverRepository = ServerRepository();
  final MCPService _mcpService = MCPService();

  // Signals 状态
  final servers = listSignal<ServerEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  // 业务方法
  Future<void> loadServers() async {
    isLoading.value = true;
    error.value = null;
    try {
      servers.value = await _serverRepository.getAllServers();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ServerEntity?> getServerById(int id) async {
    try {
      return await _serverRepository.getServerById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<void> createServer(ServerEntity server) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _serverRepository.createServer(server);
      var created = server.copyWith(id: id);
      servers.value = [...servers.value, created];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateServer(ServerEntity server) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _serverRepository.updateServer(server);
      var index = servers.value.indexWhere((s) => s.id == server.id);
      if (index >= 0) {
        var updated = List<ServerEntity>.from(servers.value);
        updated[index] = server;
        servers.value = updated;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteServer(ServerEntity server) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _serverRepository.deleteServer(server.id!);
      servers.value = servers.value.where((s) => s.id != server.id).toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> emptyServers() async {
    isLoading.value = true;
    error.value = null;
    try {
      // Delete all servers
      for (var server in servers.value) {
        await _serverRepository.deleteServer(server.id!);
      }
      servers.value = [];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 连接到 MCP 服务器并获取工具列表
  Future<ServerEntity?> fetchServerTools(ServerEntity server) async {
    isLoading.value = true;
    error.value = null;
    try {
      var result = await _mcpService.connectAndGetTools(server);

      if (result['error'] != null) {
        error.value = result['error'].toString();
        return null;
      }

      // 提取工具名称列表
      var tools = <String>[];
      var toolsList = result['tools'] as List?;
      if (toolsList != null) {
        for (var tool in toolsList) {
          if (tool is Map && tool['name'] != null) {
            tools.add(tool['name'].toString());
          }
        }
      }

      // 提取服务器描述
      var serverInfo = result['serverInfo'] as Map?;
      var description = serverInfo?['name']?.toString() ?? '';
      if (serverInfo?['version'] != null) {
        description += ' v${serverInfo!['version']}';
      }

      // 更新 server entity
      var updated = server.copyWith(description: description, tools: tools);

      await _serverRepository.updateServer(updated);

      // 更新 signals 中的服务器
      var index = servers.value.indexWhere((s) => s.id == server.id);
      if (index >= 0) {
        var updatedServers = List<ServerEntity>.from(servers.value);
        updatedServers[index] = updated;
        servers.value = updatedServers;
      }

      // 断开连接
      await _mcpService.disconnect(server.id!);

      return updated;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }
}
