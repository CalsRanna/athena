import 'package:athena/provider/server.dart';
import 'package:athena/util/mcp_util.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mcp.g.dart';

@riverpod
class McpToolsNotifier extends _$McpToolsNotifier {
  @override
  Future<List<McpTool>> build() async {
    var servers = await ref.watch(serversNotifierProvider.future);
    return McpUtil.getMcpTools(servers);
  }
}
