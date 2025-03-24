import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';
import 'package:process/process.dart';

class ProcessUtil {
  static void kill(Process process) {
    process.kill();
  }

  static void listenStderr(Process process) {
    var stream = process.stderr.transform(utf8.decoder);
    stream.listen(
      (error) => LoggerUtil.logger.e(error),
      onError: (error) => LoggerUtil.logger.e(error),
    );
  }

  static void listenStdout(Process process, void Function(String) onData) {
    var splitter = LineSplitter();
    var stream = process.stdout.transform(utf8.decoder).transform(splitter);
    stream.listen(onData, onError: (error) => LoggerUtil.logger.e(error));
  }

  static Future<Process> start(McpServerOption option) async {
    var command = [option.command, ...option.args];
    return LocalProcessManager().start(command, environment: option.env);
  }

  static Future<void> writeNotification(
    Process process,
    McpJsonRpcNotification notification,
  ) async {
    process.stdin.writeln(jsonEncode(notification.toJson()));
    await process.stdin.flush();
  }

  static Future<void> writeRequest(
    Process process,
    McpJsonRpcRequest request,
  ) async {
    process.stdin.writeln(jsonEncode(request.toJson()));
    await process.stdin.flush();
  }
}
