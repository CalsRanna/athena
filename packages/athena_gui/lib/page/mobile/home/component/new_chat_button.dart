import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 首页的主操作入口。主路径按钮从 Primary CTA 派生（DESIGN.md §2）。
class NewChatButton extends StatelessWidget {
  const NewChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: AthenaPrimaryButton(
          onTap: () => MobileChatRoute().push<void>(context),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus),
                SizedBox(width: 8),
                Text('New Session'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
