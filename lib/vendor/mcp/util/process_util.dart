import 'dart:convert';
import 'dart:io';

import 'package:athena/vendor/mcp/message.dart';
import 'package:athena/vendor/mcp/server/server_option.dart';
import 'package:athena/vendor/mcp/util/logger_util.dart';
import 'package:process/process.dart';

class ProcessUtil {
  static String get defaultPath {
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
    return '${presetPaths.join(':')}:$originalPath';
  }

  static void kill(Process process) {
    process.kill();
  }

  static void listenStderr(Process process, void Function(String) onData) {
    var stream = process.stderr.transform(utf8.decoder);
    stream.listen(onData, onError: (error) => LoggerUtil.logger.e(error));
  }

  static void listenStdout(Process process, void Function(String) onData) {
    var splitter = LineSplitter();
    var stream = process.stdout.transform(utf8.decoder).transform(splitter);
    stream.listen(onData, onError: (error) => LoggerUtil.logger.e(error));
  }

  static Future<ProcessResult> run(String command) async {
    var environment = Map<String, String>.from(Platform.environment);
    environment['PATH'] = defaultPath;
    return LocalProcessManager().run(
      command.split(' '),
      environment: environment,
      includeParentEnvironment: true,
      runInShell: true,
    );
  }

  static Future<Process> start(McpServerOption option) async {
    var command = [option.command, ...option.args];
    var environment = Map<String, String>.from(Platform.environment);
    environment['PATH'] = defaultPath;
    environment.addAll(option.env);
    LoggerUtil.logger.d('Environments: $environment');
    return LocalProcessManager().start(
      command,
      environment: environment,
      includeParentEnvironment: true,
      runInShell: true,
    );
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
