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
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.5)
                            ],
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Watcher((context, ref, child) => Text(
                              '超级VIP',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                            )),
                      ),
                      const SizedBox(height: 8),
                      Watcher(
                        (context, ref, child) => Text(
                          '过期时间：${formatExpireDate(ref.read(accountCreator).expireDate)}',
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
                              text: '${ref.read(accountCreator).balance} / ',
                              style: Theme.of(context).textTheme.headlineLarge,
                              children: [
                                TextSpan(
                                  text: '${ref.read(accountCreator).amount}',
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
                            '${ref.read(accountCreator).gpt4}',
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
