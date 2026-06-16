abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema

  Future<String> execute(Map<String, dynamic> args);
}
