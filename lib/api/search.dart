import 'package:athena/schema/tool.dart';
import 'package:tavily_dart/tavily_dart.dart';

class SearchApi {
  Future<List<SearchResult>> search(String query, {required Tool tool}) async {
    final client = TavilyClient();
    var request = SearchRequest(apiKey: tool.key, query: query);
    final response = await client.search(request: request);
    return response.results;
  }
}
