import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_theme.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('${platform.name} 图标按钮保持桌面密度且边缘可点', (tester) async {
      var navigationTaps = 0;
      var ghostTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAthenaThemeData(
            AthenaColorMode.light,
          ).copyWith(platform: platform),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AthenaIconButton(
                    icon: LucideIcons.plus,
                    onTap: () => navigationTaps++,
                  ),
                  AthenaGhostIconButton(
                    icon: LucideIcons.x,
                    onTap: () => ghostTaps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final navigation = find.byType(AthenaIconButton);
      final ghost = find.byType(AthenaGhostIconButton);
      expect(tester.getSize(navigation), const Size(32, 32));
      expect(tester.getSize(ghost), const Size(28, 28));
      await tester.tapAt(tester.getTopLeft(navigation) + const Offset(1, 1));
      await tester.tapAt(tester.getTopLeft(ghost) + const Offset(1, 1));
      expect(navigationTaps, 1);
      expect(ghostTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
