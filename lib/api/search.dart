import 'package:tavily_dart/tavily_dart.dart';

class SearchApi {
  Future<String> search(String query) async {
    // var uri = Uri.parse('https://api.tavily.com/search');
    // var headers = {
    //   'Authorization': 'Bearer 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',
    //   // 'Content-Type': 'application/json',
    // };
    // var body = jsonEncode({'query': '哪吒2票房'});
    // var response = await http.post(uri, body: body, headers: headers);
    // print(response.body);
    // return response.body;
    final client = TavilyClient();
    final res = await client.search(
      request: SearchRequest(
        apiKey: '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',
        query: query,
      ),
    );
    return res.results.toString();
  }
}
