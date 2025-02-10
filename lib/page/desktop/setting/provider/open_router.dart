import 'package:athena/schema/model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/switch.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingProviderOpenRouterPage extends StatelessWidget {
  const DesktopSettingProviderOpenRouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    var models = <Model>[];
    var children = models.map(_itemBuilder).toList();
    return AScaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        children: [
          Row(
            children: [
              Text(
                'Open Router',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(HugeIcons.strokeRoundedLinkSquare02, color: Colors.white),
              Spacer(),
              ASwitch(value: true, onChanged: (_) {})
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: AFormTileLabel(title: 'API Key'),
              ),
              Expanded(child: AInput(controller: TextEditingController()))
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: AFormTileLabel(title: 'API URL'),
              ),
              Expanded(
                child: AInput(
                  controller: TextEditingController(),
                  placeholder: 'https://openrouter.ai/api/v1',
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: AFormTileLabel(title: 'Connect'),
              ),
              Spacer(),
              ASecondaryButton(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Check'),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Models',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 12),
          Text(
            '查看OpenRouter文档和模型获取更多详情',
            style: TextStyle(
              color: Color(0xFFC2C2C2),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          )
        ],
      ),
    );
  }

  Widget _itemBuilder(Model model) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          model.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(width: 12),
                        ATag.extraSmall(text: model.value),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      r'发布于2024-06-20 输入$3.00/M 输出$15.00/M',
                      style: TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    )
                  ],
                ),
              ),
              ASwitch(onChanged: (_) {}, value: true)
            ],
          ),
        ),
      ),
    );
    // return GestureDetector(
    //   behavior: HitTestBehavior.opaque,
    //   onSecondaryTapUp: (details) => showContextMenu(details, model),
    //   onTap: () => updateModel(model),
    //   child: ATag(selected: this.model == model.value, text: model.name),
    // );
  }
}
