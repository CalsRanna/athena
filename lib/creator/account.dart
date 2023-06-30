import 'package:athena/model/liaobots_account.dart';
import 'package:creator/creator.dart';

final accountCreator = Creator.value(
  const LiaobotsAccount(amount: 0, balance: 0, gpt4: 0, expireDate: 0),
  name: 'accountCreator',
);
