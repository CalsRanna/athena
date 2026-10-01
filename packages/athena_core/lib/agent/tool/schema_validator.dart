/// 基于工具 JSON Schema 做基本参数校验。
///
/// 只实现内置工具实际使用的约束；嵌套对象和数组同样递归校验。
abstract final class SchemaValidator {
  /// 校验 [args] 是否匹配 [parameters] JSON Schema。
  ///
  /// 返回 null 表示通过，否则返回人类可读的错误消息。
  static String? validate(
    Map<String, dynamic> parameters,
    Map<String, dynamic> args,
  ) {
    return _validateValue('', args, parameters);
  }

  static String? _validateValue(
    String name,
    dynamic value,
    Map<String, dynamic> schema,
  ) {
    final typeError = _checkType(name, value, schema);
    if (typeError != null) return typeError;
    final choices = schema['enum'] as List?;
    if (choices != null && !choices.contains(value)) {
      return 'Parameter "$name" must be one of ${choices.join(', ')}';
    }
    if (value is num) {
      final minimum = schema['minimum'] as num?;
      final maximum = schema['maximum'] as num?;
      if (minimum != null && value < minimum) {
        return 'Parameter "$name" must be >= $minimum';
      }
      if (maximum != null && value > maximum) {
        return 'Parameter "$name" must be <= $maximum';
      }
    }
    if (value is String) {
      final length = value.runes.length;
      final min = schema['minLength'] as int?;
      final max = schema['maxLength'] as int?;
      if (min != null && length < min || max != null && length > max) {
        return 'Parameter "$name" has an invalid string length ($length)';
      }
    }
    if (value is Map<String, dynamic>) {
      for (final field in _extractRequired(schema)) {
        if (!value.containsKey(field)) {
          return 'Missing required parameter: "${name.isEmpty ? field : '$name.$field'}"';
        }
      }
      final properties = schema['properties'] as Map<String, dynamic>?;
      if (properties != null) {
        for (final entry in value.entries) {
          final child = properties[entry.key] as Map<String, dynamic>?;
          if (child == null) {
            if (schema['additionalProperties'] == false) {
              return 'Unknown parameter: "${entry.key}"';
            }
            continue;
          }
          final error = _validateValue(
            name.isEmpty ? entry.key : '$name.${entry.key}',
            entry.value,
            child,
          );
          if (error != null) return error;
        }
      }
    }
    if (value is List) {
      final min = schema['minItems'] as int?;
      final max = schema['maxItems'] as int?;
      if (min != null && value.length < min ||
          max != null && value.length > max) {
        return 'Parameter "$name" has an invalid array length (${value.length})';
      }
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        for (final (index, item) in value.indexed) {
          final error = _validateValue('$name[$index]', item, items);
          if (error != null) return error;
        }
      }
    }
    return null;
  }

  static String? _checkType(
    String name,
    dynamic value,
    Map<String, dynamic> schema,
  ) {
    final expectedType = schema['type'] as String?;
    if (expectedType == null) return null;

    switch (expectedType) {
      case 'string':
        if (value is! String) return _typeError(name, 'string', value);
        break;
      case 'number':
        if (value is! num) return _typeError(name, 'number', value);
        break;
      case 'integer':
        if (value is! int) return _typeError(name, 'integer', value);
        break;
      case 'boolean':
        if (value is! bool) return _typeError(name, 'boolean', value);
        break;
      case 'array':
        if (value is! List) return _typeError(name, 'array', value);
        break;
      case 'object':
        if (value is! Map<String, dynamic>) {
          return _typeError(name, 'object', value);
        }
        break;
    }

    return null;
  }

  static List<String> _extractRequired(Map<String, dynamic> parameters) {
    final list = parameters['required'];
    if (list is List) {
      return list.cast<String>();
    }
    return [];
  }

  static String _typeError(String name, String expected, dynamic actual) {
    return 'Parameter "$name" expected type "$expected", got "${actual.runtimeType}"';
  }
}
