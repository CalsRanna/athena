import 'dart:async';

import 'package:athena/util/proxy.dart';
import 'package:http/http.dart' as http;

mixin Api {
  final String model = 'gpt-4-0125-preview';

  Future<dynamic> post({Object? body, required String url}) async {
    final uri = Uri.parse('${ProxyConfig.instance.url}$url');
    final headers = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer ${ProxyConfig.instance.key}'
    };
    final response = await http.post(uri, body: body, headers: headers);
    return response.body;
  }

  Future<dynamic> get({required String url}) async {
    var uri = Uri.parse('${ProxyConfig.instance.url}$url');
    if (url.startsWith('http')) uri = Uri.parse(url);
    final headers = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer ${ProxyConfig.instance.key}'
    };
    final response = await http.get(uri, headers: headers);
    return response.body;
  }
}
