import 'dart:convert';

import 'package:athena/model/tool_call.dart';
import 'package:athena/schema/server.dart';
import 'package:athena/util/logger_util.dart';
import 'package:athena/vendor/mcp/client/stdio_client.dart';
import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/tool/tool.dart';

class McpUtil {
  static Map<String, McpStdioClient> clients = {};

  static Future<List<McpTool>> getMcpTools(List<Server> servers) async {
    List<McpTool> combinedTools = [];
    for (var server in servers) {
      if (!server.enabled) continue;
      if (!clients.containsKey(server.name)) {
        var environments = server.environments;
        if (environments.isEmpty) environments = '{}';
        var json = {
          'command': server.command,
          'args': server.arguments.split(' '),
          'env': jsonDecode(environments.replaceAll(r'\', r'\\'))
        };
        var option = McpServerOption.fromJson(json);
        clients[server.name] = McpStdioClient(option: option);
        try {
          await clients[server.name]!.initialize();
        } on Exception catch (error) {
          LoggerUtil.logger.e('Failed to initialize client: $error');
          continue;
        }
      }
      var client = clients[server.name]!;
      try {
        var tools = await client.listTools();
        combinedTools.addAll(tools);
      } on Exception catch (error) {
        LoggerUtil.logger.e('Failed to list tools: $error');
        continue;
      }
    }
    return combinedTools;
  }

  static Future<Server?> getServer(
    ToolCall toolCall, {
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

  static Future<McpJsonRpcResponse> callTool(
    McpTool tool,
    Server server, {
    Map<String, dynamic>? arguments,
  }) async {
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
    return client.callTool(tool, arguments: arguments);
  }
}
