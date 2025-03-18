import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';

class MobileLanguageSelectDialog extends StatelessWidget {
  final void Function(String)? onTap;
  const MobileLanguageSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    var languages = [
      'Chinese',
      'English',
      'Arabic',
      'French',
      'German',
      'Italian',
      'Japanese',
      'Korean',
      'Portuguese',
      'Russian',
      'Spanish',
    ];
    List<Widget> children = [SizedBox(height: 16)];
    for (var language in languages) {
      var tile = AthenaBottomSheetTile(
        onTap: () => handleTap(language),
        title: language,
      );
      children.add(tile);
    }
    return ListView(shrinkWrap: true, children: children);
  }

  void handleTap(String language) {
    onTap?.call(language);
    AthenaDialog.dismiss();
  }
}
