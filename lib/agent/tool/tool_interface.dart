enum DangerLevel { safe, needsApproval, forbidden }

abstract class Tool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters; // JSON Schema
  DangerLevel get dangerLevel;

  Future<String> execute(Map<String, dynamic> args);
}
