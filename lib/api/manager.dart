import 'dart:convert';

import 'package:athena/schema/model.dart';
import 'package:athena/util/proxy.dart';
import 'package:http/http.dart';

class ManagerApi {
  Future<List<Model>> getModels() async {
    Future<List<String>> getValues() async {
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

    final values = await getValues();
    values.sort((a, b) => a.compareTo(b));
    final models = values.map((value) {
      final patterns = value.split('-');
      final name = patterns
          .map((pattern) {
            if (pattern.startsWith('20')) return '';
            return pattern[0].toUpperCase() + pattern.substring(1);
          })
          .join(' ')
          .trim();
      return Model()
        ..name = name
        ..value = value;
    }).toList();
    return models;
  }
}
