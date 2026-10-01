import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/agent/tool/tool_result.dart';
import 'package:athena_core/agent/tool/web_fetch_tool.dart';
import 'package:test/test.dart';

void main() {
  late _Client client;
  Future<ToolExecutionResult> fetch(
    List<_Response> responses, {
    Map<String, dynamic> args = const {},
    Duration timeout = const Duration(seconds: 1),
    Future<void>? cancelSignal,
  }) {
    client = _Client(responses);
    final tool = WebFetchTool(timeout: timeout);
    final params = {
      'url': 'https://example.com/docs/index.html',
      'format': 'html',
      ...args,
    };
    return HttpOverrides.runZoned(
      () => cancelSignal == null
          ? tool.executeResult(params)
          : tool.executeCancellable(params, cancelSignal: cancelSignal),
      createHttpClient: (_) => client,
    );
  }

  _Response response(
    String text, {
    String type = 'text/plain',
    int status = 200,
    String? location,
  }) => _Response(
    Stream.value(utf8.encode(text)),
    type: type,
    statusCode: status,
    location: location,
  );

  test('UTF-8 and quoted charset preserve non-ASCII content', () async {
    for (final type in [
      'text/html',
      'text/html; charset="utf-8"',
      'application/json',
    ]) {
      final result = await fetch([response('中文😀', type: type)]);
      expect(result.text, endsWith('中文😀'));
      expect(result.status, ToolResultStatus.success);
      expect(client.closed, isTrue);
    }
    final latin = await fetch([
      _Response(
        Stream.value(latin1.encode('café')),
        type: 'text/plain; charset=iso-8859-1',
      ),
    ]);
    expect(latin.text, endsWith('café'));
  });

  test(
    'a single oversized chunk reports truncation without Content-Length',
    () async {
      final result = await fetch([response('x' * (200 * 1024 + 1))]);
      expect(result.text, contains('Response truncated'));
      expect(result.status, ToolResultStatus.success);
    },
  );

  test(
    'UTF-8 truncation removes only an incomplete trailing code point',
    () async {
      final result = await fetch([
        response(
          '${'x' * (200 * 1024 - 1)}中',
          type: 'text/plain; charset=utf-8',
        ),
      ]);
      expect(result.status, ToolResultStatus.success);
      expect(result.text, contains('Response truncated'));
      final malformed = await fetch([
        _Response(
          Stream.value([0xFF, 0x61]),
          type: 'text/plain; charset=utf-8',
        ),
      ]);
      expect(malformed.status, ToolResultStatus.executionError);
    },
  );

  test(
    'a redirect without Location returns its unread response body',
    () async {
      final result = await fetch([response('redirect message', status: 302)]);
      expect(result.status, ToolResultStatus.success);
      expect(result.text, contains('redirect message'));
    },
  );

  test(
    'redirect limit returns the final body without a second subscription',
    () async {
      final responses = List.generate(
        6,
        (i) => response('body $i', status: 302, location: '/next/$i'),
      );
      final result = await fetch(responses);
      expect(client.requests, hasLength(6));
      expect(result.text, contains('body 5'));
    },
  );

  test('the final URL resolves relative markdown links', () async {
    final result = await fetch(
      [
        response('', status: 302, location: '/new/index.html'),
        response('<a href="guide">Guide</a>', type: 'text/html'),
      ],
      args: {'format': 'markdown'},
    );
    expect(result.text, contains('[Guide](https://example.com/new/guide)'));
  });

  test(
    'cross-origin redirects never send another request or drain a hanging body',
    () async {
      final hanging = StreamController<List<int>>();
      addTearDown(() {
        unawaited(hanging.close());
      });
      final result = await fetch([
        _Response(
          hanging.stream,
          statusCode: 302,
          location: 'https://other.example/path',
        ),
      ]);
      expect(client.requests, hasLength(1));
      expect(result.text, contains('different origin'));
      expect(client.closed, isTrue);
    },
  );

  test('one deadline covers a stalled redirect drain', () async {
    final hanging = StreamController<List<int>>();
    addTearDown(() {
      unawaited(hanging.close());
    });
    final result = await fetch([
      _Response(hanging.stream, statusCode: 302, location: '/next'),
    ], timeout: const Duration(milliseconds: 20));
    expect(result.status, ToolResultStatus.executionError);
    expect(result.text, contains('TimeoutException'));
    expect(client.closed, isTrue);
  });

  test(
    'cancellation ends a stalled body without depending on client-close errors',
    () async {
      final hanging = StreamController<List<int>>();
      addTearDown(() {
        unawaited(hanging.close());
      });
      final cancel = Completer<void>();
      final result = fetch([
        _Response(hanging.stream),
      ], cancelSignal: cancel.future);
      await Future<void>.delayed(Duration.zero);
      cancel.complete();
      await expectLater(result, throwsA(isA<CancelledException>()));
      expect(client.closed, isTrue);
    },
  );
}

class _Headers implements HttpHeaders {
  _Headers(this.values);
  final Map<String, String> values;
  @override
  String? value(String name) => values[name];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(
    this.stream, {
    String type = 'text/plain',
    this.statusCode = 200,
    String? location,
  }) : headers = _Headers({
         'content-type': type,
         if (location != null) 'location': location,
       });
  final Stream<List<int>> stream;
  @override
  final _Headers headers;
  @override
  final int statusCode;
  @override
  String get reasonPhrase => 'mock';
  @override
  int get contentLength => -1;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  final headers = _Headers({});
  @override
  set followRedirects(bool value) {}
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.responses);
  final List<_Response> responses;
  final List<Uri> requests = [];
  bool closed = false;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add(url);
    return _Request(responses.removeAt(0));
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
