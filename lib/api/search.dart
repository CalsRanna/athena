import 'package:tavily_dart/tavily_dart.dart';

class SearchApi {
  Future<List<SearchResult>> search(String query) async {
    final client = TavilyClient();
    var request = SearchRequest(
      apiKey: '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',
      query: query,
    );
    final response = await client.search(request: request);
    return response.results;
  }
}
