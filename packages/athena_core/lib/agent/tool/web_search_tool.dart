import 'dart:async';
import 'dart:convert';

import 'package:athena_core/agent/cancel_token.dart';
import 'package:athena_core/storage/key_value_store.dart';
import 'package:http/http.dart' as http;

import 'tool_interface.dart';

class WebSearchTool implements Tool, CancellableTool {
  /// API key 存放依赖注入的 [KeyValueStore]（GUI=SharedPreferences，TUI=JSON 文件）。
  WebSearchTool({KeyValueStore? store}) : _store = store;

  final KeyValueStore? _store;

  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => true;

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  static const _keyBraveApiKey = 'brave_api_key';
  static const _defaultTimeout = Duration(seconds: 15);
  static const _maxResults = 10;

  @override
  String get name => 'web_search';

  @override
  String get description => 'Search the web using Brave Search. '
      'Returns a list of results with title, URL, and description. '
      'Use when you need up-to-date information beyond your knowledge cutoff. '
      'For reading full page content, use web_fetch on the result URLs. '
      'Requires a Brave Search API key in settings.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query.',
          },
        },
        'required': ['query'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) =>
      _execute(args, onUpdate: onUpdate);

  @override
  Future<String> executeCancellable(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    required Future<void> cancelSignal,
  }) =>
      _execute(
        args,
        onUpdate: onUpdate,
        cancelSignal: cancelSignal,
      );

  Future<String> _execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
    Future<void>? cancelSignal,
  }) async {
    final query = args['query'] as String;

    final store = _store;
    if (store == null) {
      return 'Error: Brave Search API key store not configured.';
    }
    final apiKey = await store.getString(_keyBraveApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: Brave Search API key not configured. '
          'Set it in settings with key "$_keyBraveApiKey". '
          'Get a free key at https://brave.com/search/api/';
    }

    final uri = Uri.https(
      'api.search.brave.com',
      '/res/v1/web/search',
      {'q': query, 'count': _maxResults.toString()},
    );

    var cancelled = false;
    try {
      final client = http.Client();
      var completed = false;
      if (cancelSignal != null) {
        unawaited(cancelSignal.then((_) {
          cancelled = true;
          if (!completed) client.close();
        }));
      }
      http.Response response;
      try {
        response = await client
            .get(uri, headers: {
              'Accept': 'application/json',
              'Accept-Encoding': 'gzip',
              'X-Subscription-Token': apiKey,
            })
            .timeout(_defaultTimeout);
      } finally {
        completed = true;
        client.close();
      }

      if (response.statusCode != 200) {
        return 'Error: Brave Search returned ${response.statusCode}: ${response.body}';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final web = data['web'] as Map<String, dynamic>?;
      final results = web?['results'] as List<dynamic>?;

      if (results == null || results.isEmpty) {
        return 'No results found for "$query".';
      }

      final buffer = StringBuffer();
      for (var i = 0; i < results.length; i++) {
        final r = results[i] as Map<String, dynamic>;
        final title = r['title'] as String? ?? '(no title)';
        final url = r['url'] as String? ?? '';
        final description = r['description'] as String? ?? '';
        buffer.writeln('${i + 1}. $title');
        buffer.writeln('   $url');
        if (description.isNotEmpty) {
          buffer.writeln('   $description');
        }
        buffer.writeln();
      }
      return buffer.toString().trim();
    } on http.ClientException catch (e) {
      if (cancelled) throw const CancelledException();
      return 'Error: Search request failed: ${e.message}';
    } catch (e) {
      if (cancelled) throw const CancelledException();
      return 'Error: $e';
    }
  }
}
