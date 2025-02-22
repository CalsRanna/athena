import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileSentinelListPage extends ConsumerWidget {
  const MobileSentinelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    var state = ref.watch(provider);
    var listView = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return AScaffold(
      appBar: AAppBar(title: const Text('Sentinel')),
      body: Stack(
        children: [
          listView,
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => navigateSentinelFormPage(context),
              child: Container(
                decoration: ShapeDecoration(
                  color: Color(0xFF161616),
                  shape: StadiumBorder(),
                ),
                padding: EdgeInsets.fromLTRB(8, 12, 12, 12),
                margin: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      height: 24,
                      width: 24,
                      child: Icon(
                        HugeIcons.strokeRoundedAdd01,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add a sentinel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void navigateSentinelFormPage(BuildContext context) {
    MobileSentinelFormRoute().push(context);
  }

  Widget _buildData(List<Sentinel> sentinels) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _Tile(sentinel: sentinels[index]),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.sentinel});
  final Sentinel sentinel;
  @override
  Widget build(BuildContext context) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    const descriptionTextStyle = TextStyle(
      color: Color(0xFF616161),
      fontSize: 12,
    );
    var children = [
      Text(sentinel.name, style: nameTextStyle),
      Text(sentinel.description, style: descriptionTextStyle),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showBottomSheet,
      child: container,
    );
  }

  void _showBottomSheet() {
    ADialog.show(_ActionDialog(sentinel: sentinel));
  }
}

class _ActionDialog extends ConsumerWidget {
  final Sentinel sentinel;
  const _ActionDialog({required this.sentinel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var editWidgets = [
      const SizedBox(height: 12),
      _OutlinedButton(
        text: 'Edit',
        onTap: () => navigateSentinelFormPage(context),
      ),
      const SizedBox(height: 12),
      _OutlinedButton(
        onTap: () => _showDeleteConfirmDialog(context),
        text: 'Delete',
      ),
    ];
    var children = [
      APrimaryButton(
        child: Center(child: Text('Start Chat')),
        onTap: () => navigateChatPage(context, ref),
      ),
      if (sentinel.name != 'Athena') ...editWidgets,
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    ADialog.dismiss();
    ADialog.confirm(
      'Are you sure you want to delete this sentinel?',
      onConfirmed: _confirmDelete,
    );
  }

  void _confirmDelete(BuildContext context) {
    var container = ProviderScope.containerOf(context);
    var provider = sentinelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.destroy(sentinel);
    ADialog.dismiss();
    ADialog.success('Sentinel deleted successfully');
  }

  Future<void> navigateChatPage(BuildContext context, WidgetRef ref) async {
    ADialog.dismiss();
    var viewModel = ChatViewModel(ref);
    var chat = await viewModel.createChat(sentinel: sentinel);
    if (!context.mounted) return;
    MobileChatRoute(chat: chat).push(context);
  }

  void navigateSentinelFormPage(BuildContext context) {
    ADialog.dismiss();
    MobileSentinelFormRoute(sentinel: sentinel).push(context);
  }
}

class _OutlinedButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;
  const _OutlinedButton({this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return ASecondaryButton(
      onTap: onTap,
      child: Center(child: Text(text, style: textStyle)),
    );
  }
}
