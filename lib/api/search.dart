import 'package:http/http.dart' as http;

class SearchApi {
  Future<String> search(String query) async {
    var uri = Uri.parse('https://api.tavily.com/search');
    var headers = {
      'Authorization': 'Bearer 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'
    };
    var body = {'query': query};
    var response = await http.post(uri, body: body, headers: headers);
    return response.body;
  }
}
