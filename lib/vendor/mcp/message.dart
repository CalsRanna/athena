import 'dart:convert';

class McpJsonRpcNotification {
  final String jsonrpc;
  final String method;
  final Map<String, dynamic>? params;

  McpJsonRpcNotification({
    this.jsonrpc = '2.0',
    required this.method,
    this.params,
  });

  factory McpJsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return McpJsonRpcNotification(
      jsonrpc: json['jsonrpc']?.toString() ?? '2.0',
      method: json['method']?.toString() ?? '',
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    json.putIfAbsent('jsonrpc', () => jsonrpc);
    json.putIfAbsent('method', () => method);
    if (params != null) json.putIfAbsent('params', () => params);
    return json;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class McpJsonRpcRequest {
  final String id;
  final String jsonrpc;
  final String method;
  final Map<String, dynamic>? params;

  McpJsonRpcRequest({this.jsonrpc = '2.0', required this.method, this.params})
      : id = DateTime.now().millisecondsSinceEpoch.toString();

  factory McpJsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return McpJsonRpcRequest(
      jsonrpc: json['jsonrpc']?.toString() ?? '2.0',
      method: json['method']?.toString() ?? '',
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    json.putIfAbsent('id', () => id);
    json.putIfAbsent('jsonrpc', () => jsonrpc);
    json.putIfAbsent('method', () => method);
    if (params != null) json.putIfAbsent('params', () => params);
    return json;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class McpJsonRpcResponse {
  final String id;
  final dynamic error;
  final String jsonrpc;
  final dynamic result;
  McpJsonRpcResponse({
    required this.id,
    this.error,
    this.jsonrpc = '2.0',
    this.result,
  });

  factory McpJsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return McpJsonRpcResponse(
      id: json['id']?.toString() ?? '',
      jsonrpc: json['jsonrpc']?.toString() ?? '2.0',
      result: json['result'],
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    json.putIfAbsent('id', () => id);
    json.putIfAbsent('jsonrpc', () => jsonrpc);
    if (result != null) json.putIfAbsent('result', () => result);
    if (error != null) json.putIfAbsent('error', () => error);
    return json;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
