import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:dart_mcp/client.dart';
import 'package:stream_channel/stream_channel.dart';

extension McpClientExtension on MCPClient {
  Future<ServerConnection> connectStdioServerWithEnvironment(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    Sink<String>? protocolLogSink,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      environment: environment,
    );
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderr.writeln('[StdErr from server $command]: $line');
        });
    final channel =
        StreamChannel.withCloseGuarantee(process.stdout, process.stdin)
            .transform(StreamChannelTransformer.fromCodec(utf8))
            .transformStream(const LineSplitter())
            .transformSink(
              StreamSinkTransformer.fromHandlers(
                handleData: (data, sink) {
                  sink.add('$data\n');
                },
              ),
            );
    final connection = connectServer(channel, protocolLogSink: protocolLogSink);
    unawaited(connection.done.then((_) => process.kill()));
    return connection;
  }
}
