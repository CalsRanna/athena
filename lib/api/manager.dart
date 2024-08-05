import 'dart:convert';

import 'package:athena/schema/model.dart';
import 'package:athena/util/proxy.dart';
import 'package:http/http.dart';

class ManagerApi {
  Future<List<Model>> getModels() async {
    final values = await _getValues();
    final models = values.map((value) {
      final name = _getName(value);
      return Model()
        ..name = name
        ..value = value;
    }).toList();
    return models;
  }

  String _getName(String value) {
    final patterns = value.split('-');
    final filtered = patterns.where((pattern) => !pattern.startsWith('20'));
    return filtered.map((pattern) {
      final name = pattern[0].toUpperCase() + pattern.substring(1);
      return name.trim();
    }).join(' ');
  }

  Future<List<String>> _getValues() async {
    final uri = Uri.parse('https://aiproxy.io/api/user/listApiKey');
    final headers = {
      "Content-Type": 'application/json',
      "Api-Key": ProxyConfig.instance.key
    };
    try {
      final response = await get(uri, headers: headers);
      final json = jsonDecode(response.body);
      return List<String>.from(json['data'][0]['modelPermission']);
    } catch (error) {
      return ['gpt-4o', 'gpt-4o-mini'];
    }
  }
}
