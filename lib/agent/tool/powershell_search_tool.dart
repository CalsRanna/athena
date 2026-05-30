import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';

import 'tool_interface.dart';

class PowerShellSearchTool implements Tool {
  final PathSandbox sandbox;

  PowerShellSearchTool({required this.sandbox});

  @override
  String get name => 'search';

  @override
  String get description => 'Search for files by pattern or search file '
      'contents with regex. Use when you need to locate files or code. '
      'Uses Select-String for content search and Get-ChildItem for file search.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'pattern': {
            'type': 'string',
            'description': 'The search pattern (file name glob for find, '
                'regex for grep in content).',
          },
          'path': {
            'type': 'string',
            'description': 'The directory path to search in. Defaults to the '
                'current working directory.',
          },
          'type': {
            'type': 'string',
            'enum': ['grep', 'find'],
            'description': 'Search type: "grep" searches file contents, '
                '"find" searches file names.',
          },
        },
        'required': ['pattern'],
      };

  @override
  DangerLevel get dangerLevel => DangerLevel.needsApproval;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final pattern = args['pattern'] as String;
    final path = args['path'] as String? ?? Directory.current.path;
    final type = args['type'] as String? ?? 'grep';

    if (!sandbox.canRead(path)) {
      return 'Error: path "$path" is in a restricted system area and cannot be accessed.';
    }

    final escapedPath = path.replaceAll("'", "''");
    final escapedPattern = pattern.replaceAll("'", "''");

    try {
      final ProcessResult results;
      if (type == 'find') {
        results = await Process.run(
          'powershell.exe',
          [
            '-Command',
            "Get-ChildItem -Path '$escapedPath' -Recurse -Filter '$escapedPattern' | Select-Object -ExpandProperty FullName",
          ],
          workingDirectory: path,
        );
      } else {
        // PowerShell native array syntax for -Include; brace expansion is bash-only.
        const includeArray =
            "@('*.dart','*.yaml','*.md','*.json','*.js','*.ts','*.py','*.java','*.kt','*.swift','*.c','*.cpp','*.h','*.hpp','*.rs','*.go','*.rb','*.php','*.html','*.css','*.sql','*.xml','*.toml','*.cfg')";
        results = await Process.run(
          'powershell.exe',
          [
            '-Command',
            "Get-ChildItem -Path '$escapedPath' -Recurse -Include $includeArray -File | Select-String -Pattern '$escapedPattern'",
          ],
          workingDirectory: path,
        );
      }

      final output = '${results.stdout}'.trim();
      if (output.isEmpty) return 'No results found for "$pattern"';

      final lines = output.split('\n');
      if (lines.length > 50) {
        return '${lines.take(50).join('\n')}\n\n... and ${lines.length - 50} more results';
      }
      return output;
    } catch (e) {
      return 'Error executing search: $e';
    }
  }
}
