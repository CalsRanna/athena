import 'package:athena/entity/tool_entity.dart';
import 'package:tavily_dart/tavily_dart.dart';

/// SearchService 负责网络搜索相关的网络请求
class SearchService {
  /// 使用 Tavily 进行搜索
  Future<List<SearchResult>> search(String query, {required ToolEntity tool}) async {
    final client = TavilyClient();
    var request = SearchRequest(
      apiKey: tool.key,
      maxResults: 10,
      query: query,
    );
    final response = await client.search(request: request);
    return response.results;
  }
}
