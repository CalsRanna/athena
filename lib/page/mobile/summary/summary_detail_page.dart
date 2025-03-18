import 'dart:io';

import 'package:athena/component/button.dart';
import 'package:athena/page/mobile/summary/component/summary_list_tile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/summary.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/summary.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/summary.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/markdown.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileSummaryDetailPage extends ConsumerWidget {
  final Summary summary;
  const MobileSummaryDetailPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(summaryNotifierProvider(summary.id));
    var body = switch (state) {
      AsyncData(:final value) => _buildData(ref, value),
      _ => const SizedBox(),
    };
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Summary')),
      body: body,
    );
  }

  Widget _buildData(WidgetRef ref, Summary summary) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        MobileSummaryListTile(summary: summary),
        SizedBox(height: 24),
        _buildTitle(ref),
        SizedBox(height: 16),
        _SummaryContent(summary: summary),
        SafeArea(top: false, child: const SizedBox()),
      ],
    );
  }

  Widget _buildTitle(WidgetRef ref) {
    var streaming = ref.watch(streamingNotifierProvider);
    const titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var textButton = AthenaTextButton(
      onTap: () => SummaryViewModel(ref).summarize(summary),
      text: 'Summarize',
    );
    var indicator = SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    var children = [
      Text('Summary', style: titleTextStyle),
      if (streaming) const SizedBox(width: 4),
      if (streaming) indicator,
      const Spacer(),
      textButton
    ];
    return Row(children: children);
  }
}

class _SummaryContent extends StatelessWidget {
  final Summary summary;
  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildAvatar(),
      const SizedBox(width: 12),
      _buildContent(),
      _buildTrailingSpace(),
    ];
    var messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.95),
    );
    var stackChildren = [
      messageRow,
      Positioned(right: 0, child: CopyButton(onTap: handleCopy)),
    ];
    return Container(
      decoration: boxDecoration,
      padding: EdgeInsets.fromLTRB(12, 12, 16, 16),
      child: Stack(children: stackChildren),
    );
  }

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: summary.content));
  }

  Widget _buildAvatar() {
    var image = Image.asset(
      'asset/image/launcher_icon_ios_512x512.jpg',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      height: 36,
      width: 36,
    );
    return ClipOval(child: image);
  }

  Widget _buildContent() {
    var wrappedMessage = Message()..content = summary.content;
    var markdown = AthenaMarkdown(
      engine: AthenaMarkdownEngine.flutter,
      message: wrappedMessage,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minHeight: 36),
      child: markdown,
    );
    return Expanded(child: container);
  }

  Widget _buildTrailingSpace() {
    var isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    return SizedBox(width: isDesktop ? 48 : 24);
  }
}
