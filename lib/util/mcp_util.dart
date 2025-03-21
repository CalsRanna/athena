import 'dart:convert';

import 'package:athena/model/mcp_tool_call.dart';
import 'package:athena/schema/server.dart';
import 'package:mcp_dart/mcp_dart.dart';

class McpUtil {
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

  Future<Server?> getServer(
    McpToolCall toolCall, {
    required List<Server> servers,
  }) async {
    Server? matchedServer;
    for (var server in servers) {
      var json = {
        'command': server.command,
        'args': server.arguments.split(' '),
      };
      var option = McpServerOption.fromJson(json);
      var client = McpStdioClient(option: option);
      await client.initialize();
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
    var json = {
      'command': server.command,
      'args': server.arguments.split(' '),
    };
    var option = McpServerOption.fromJson(json);
    var client = McpStdioClient(option: option);
    await client.initialize();
    var tool = toolCall.name.toString();
    var arguments = jsonDecode(toolCall.arguments.toString());
    return client.callTool(tool, arguments: arguments);
  }
}
