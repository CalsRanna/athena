import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopChatIndicator extends StatelessWidget {
  final Model? model;
  final Sentinel? sentinel;
  const DesktopChatIndicator({super.key, this.model, this.sentinel});

  @override
  Widget build(BuildContext context) {
    var children = [
      _SentinelIndicator(sentinel: sentinel),
      SizedBox(width: 8),
      _ModelIndicator(model: model),
      const Spacer(),
      const _SettingButton(),
      const SizedBox(width: 16),
    ];
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(
      border: Border(bottom: borderSide, left: borderSide),
    );
    return Container(
      decoration: boxDecoration,
      height: 50,
      padding: const EdgeInsets.only(left: 16),
      child: Row(children: children),
    );
  }
}

class _SettingButton extends StatelessWidget {
  const _SettingButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: const Icon(HugeIcons.strokeRoundedSettings01, color: Colors.white),
    );
  }

  void handleTap(BuildContext context) {
    DesktopSettingAccountRoute().push(context);
  }
}

class _ModelIndicator extends ConsumerWidget {
  final Model? model;
  const _ModelIndicator({this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (model != null) return _buildData(model!);
    var provider = modelNotifierProvider('');
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(Model model) {
    var text = Text(
      model.name,
      style: TextStyle(color: Colors.white, fontSize: 14),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: Color(0xFF161616),
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: text,
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}

class _SentinelIndicator extends ConsumerWidget {
  final Sentinel? sentinel;
  const _SentinelIndicator({this.sentinel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sentinel != null) return _buildData(sentinel!);
    var provider = sentinelNotifierProvider(0);
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(Sentinel sentinel) {
    return Text(
      sentinel.name,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
  }
}
