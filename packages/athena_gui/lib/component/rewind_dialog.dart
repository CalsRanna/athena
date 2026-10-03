import 'package:athena_gui/widget/dialog.dart';

abstract final class RewindDialog {
  static Future<bool?> confirm({
    required bool replacesDraft,
  }) => AthenaDialog.confirm(
    'Rewind to before this message? This message and all later conversation '
    'records will be removed, and its text and images restored to the composer. '
    'Queued input and background work in this session will be stopped. '
    'File changes and executed commands will not be undone. A recovery snapshot will be saved.'
    '${replacesDraft ? '\n\nYour current draft and attachments will be replaced.' : ''}',
  );
}
