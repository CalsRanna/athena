import 'dart:convert';

import 'package:athena/vendor/mcp/tool/mcp_tool_call.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/vendor/mcp/client/stdio_client.dart';
import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';

class McpUtil {
  static Map<String, McpStdioClient> clients = {};

  Future<List<McpTool>> getMcpTools(List<Server> servers) async {
    List<McpTool> combinedTools = [];
    for (var server in servers) {
      if (!clients.containsKey(server.name)) {
        var json = {
          'command': server.command,
          'args': server.arguments.split(' '),
        };
        var option = McpServerOption.fromJson(json);
        clients[server.name] = McpStdioClient(option: option);
        await clients[server.name]!.initialize();
      }
      var client = clients[server.name]!;
      var tools = await client.listTools();
      combinedTools.addAll(tools);
    }
    return combinedTools;
  }

  Future<Server?> getServer(
    McpToolCall toolCall, {
    required List<Server> servers,
  }) async {
    Server? matchedServer;
    for (var server in servers) {
      if (!clients.containsKey(server.name)) {
        var json = {
          'command': server.command,
          'args': server.arguments.split(' '),
        };
        var option = McpServerOption.fromJson(json);
        clients[server.name] = McpStdioClient(option: option);
        await clients[server.name]!.initialize();
      }
      var client = clients[server.name]!;
      var tools = await client.listTools();
      var toolNames = tools.map((tool) => tool.name);
      if (toolNames.contains(toolCall.name.toString())) {
        matchedServer = server;
        break;
      }
    }
    return matchedServer;
  }

  Future<McpJsonRpcResponse> callTool(
    McpToolCall toolCall,
    Server server,
  ) async {
    if (!clients.containsKey(server.name)) {
      var json = {
        'command': server.command,
        'args': server.arguments.split(' '),
      };
      var option = McpServerOption.fromJson(json);
      clients[server.name] = McpStdioClient(option: option);
      await clients[server.name]!.initialize();
    }
    var client = clients[server.name]!;
    var tool = toolCall.name.toString();
    Map<String, dynamic> arguments;
    try {
      arguments = jsonDecode(toolCall.arguments.toString());
    } catch (e) {
      arguments = {};
    }
    return client.callTool(tool, arguments: arguments);
  }
}
