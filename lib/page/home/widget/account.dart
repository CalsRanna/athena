import 'package:athena/creator/account.dart';
import 'package:athena/model/liaobots_account.dart';
import 'package:athena/provider/liaobots.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

class AccountWidget extends StatefulWidget {
  const AccountWidget({super.key});

  @override
  State<AccountWidget> createState() => _AccountWidgetState();
}

class _AccountWidgetState extends State<AccountWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        GestureDetector(
          onTap: updateAccount,
          child: Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            elevation: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.75),
                              Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.25)
                            ],
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Watcher((context, ref, child) => Text(
                              '超级VIP',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                            )),
                      ),
                      const SizedBox(height: 8),
                      Watcher(
                        (context, ref, child) => Text(
                          '过期时间：${formatExpireDate(ref.read(accountCreator)?.expireDate ?? 0)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: updateAccount,
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          '账户余额（¥）',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Watcher(
                          (context, ref, child) => Text.rich(
                            TextSpan(
                              text: '${ref.read(accountCreator)?.balance} / ',
                              style: Theme.of(context).textTheme.headlineLarge,
                              children: [
                                TextSpan(
                                  text: '${ref.read(accountCreator)?.amount}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: updateAccount,
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          '剩余GPT-4调用次数',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Watcher(
                          (context, ref, child) => Text(
                            '${ref.read(accountCreator)?.gpt4}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text('默认模型'),
          trailing: Text('gpt-4-0613'),
        ),
        ListTile(
          title: Text('上下文数量'),
          trailing: Text('8条对话'),
        ),
        AboutListTile(
          aboutBoxChildren: [
            Text(
              'This is an app used to talk with different ai models, basically chat gpt.',
            ),
            Text(
              'Ask me anything!',
            ),
          ],
          applicationName: 'Athena',
          applicationLegalese: 'Developed by Cals Ranna',
          applicationVersion: '1.0.0+17',
          applicationIcon: FlutterLogo(),
          child: Text('关于Athena'),
        ),
      ],
    );
  }

  String formatExpireDate(int expireDate) {
    return DateTime.fromMillisecondsSinceEpoch(expireDate)
        .toString()
        .substring(0, 10);
  }

  void updateAccount() async {
    final ref = context.ref;
    final response = await LiaobotsProvider().getAccount();
    ref.set(accountCreator, LiaobotsAccount.fromJson(response));
  }
}
