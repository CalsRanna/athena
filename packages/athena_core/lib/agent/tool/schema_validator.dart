/// 基于工具 JSON Schema 做基本参数校验。
///
/// 支持的校验维度：
/// - required 字段存在性
/// - 基础类型匹配（string / number / integer / boolean / array / object）
///
/// 不支持：nested object, oneOf/anyOf, pattern, enum 等复杂约束。
/// 这些由 LLM 自行保证，此处仅做安全兜底。
class SchemaValidator {
  SchemaValidator._();

  /// 校验 [args] 是否匹配 [parameters] JSON Schema。
  ///
  /// 返回 null 表示通过，否则返回人类可读的错误消息。
  static String? validate(Map<String, dynamic> parameters, Map<String, dynamic> args) {
    final required = _extractRequired(parameters);
    if (required.isNotEmpty) {
      for (final field in required) {
        if (!args.containsKey(field)) {
          return 'Missing required parameter: "$field"';
        }
      }
    }

    final properties = parameters['properties'] as Map<String, dynamic>?;
    if (properties == null) return null;

    for (final entry in properties.entries) {
      final propName = entry.key;
      final propSchema = entry.value as Map<String, dynamic>?;
      if (propSchema == null) continue;

      final value = args[propName];
      if (value == null) continue; // optional field, already checked for required

      final error = _checkType(propName, value, propSchema);
      if (error != null) return error;
    }

    return null;
  }

  static String? _checkType(String name, dynamic value, Map<String, dynamic> schema) {
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
        if (value is! Map<String, dynamic>) return _typeError(name, 'object', value);
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
