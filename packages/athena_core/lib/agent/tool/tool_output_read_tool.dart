import 'tool_interface.dart';
import 'tool_output_store.dart';

/// Reads only saved tool results, including on mobile without filesystem tools.
class ToolOutputReadTool extends Tool {
  ToolOutputReadTool(this.store);

  final ToolOutputStore store;

  @override
  String get name => 'tool_output_read';

  @override
  ToolRisk get risk => ToolRisk.readOnly;

  @override
  ExecutionMode get executionMode => ExecutionMode.parallel;

  @override
  String get description =>
      'Read a saved tool output by its output_id, without executing the '
      'original command or request again. offset and limit count Unicode '
      'characters (not lines or bytes), so even a long single line can be '
      'read in continuous pages. Use the returned next offset to continue.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'output_id': {'type': 'string', 'description': 'ID from a saved output.'},
      'offset': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Zero-based character offset. Defaults to 0.',
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': ToolOutputStore.pageLimit,
        'description': 'Characters to read. Defaults to 6000.',
      },
    },
    'required': ['output_id'],
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final id = args['output_id'] as String;
    final offset = args['offset'] as int? ?? 0;
    try {
      final page = await store.read(
        id,
        offset: offset,
        limit: args['limit'] as int? ?? 6000,
      );
      final next = page.hasMore
          ? 'Continue with tool_output_read(output_id="$id", '
                'offset=${page.nextOffset}, limit=6000).'
          : 'End of saved output.';
      return '[characters $offset-${page.nextOffset}, end exclusive]\n'
          '$next\n\n${page.text}';
    } catch (e) {
      return 'Error: Unable to read saved output: $e';
    }
  }
}
