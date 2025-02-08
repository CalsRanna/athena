import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileTavernPage extends StatelessWidget {
  const MobileTavernPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AScaffold(
        appBar: AAppBar(
          action: AIconButton(
            icon: HugeIcons.strokeRoundedCancel01,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          leading: const SizedBox(),
          title: const Text('Tavern'),
        ),
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('''Key aspects of a job finder app's UX analysis:
      Seamless onboarding process
      Intuitive search and filtering
      Clear and organized job listings
      Personalized job recommendations
      Easy application process
      Communication and collaboration features
      User feedback and support options
      Accessibility considerations
      Performance and speed
      Visual design and branding consistency.'''),
                      SizedBox(height: 12),
                      Text(
                        '《Story Name》',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Stories you wrote',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      colors: [
                        Color(0xFFEAEAEA).withValues(alpha: 0.17),
                        Colors.white.withValues(alpha: 0),
                      ],
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.all(1),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Color(0xFF616161),
                    ),
                    padding: EdgeInsets.all(12),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'World Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'asdkas;fdjkasl;jfd;laskdjflkasjldfkhaslkdfhlkasdhflkhj',
                          style: TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                child: APrimaryButton(
                  onTap: () => startStory(context),
                  child: Center(
                    child: Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startStory(BuildContext context) async {
    MobileStoryRoute().push(context);
    // var container = ProviderScope.containerOf(context);
    // var provider = settingNotifierProvider;
    // var setting = await container.read(provider.future);
    // var welcome = TavernApi().getTitle(model: setting.model);
    // await for (final token in welcome) {
    //   print(token);
    // }
  }
}
