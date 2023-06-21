import 'package:athena/creator/setting.dart';
import 'package:athena/main.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class AdvancedPage extends StatelessWidget {
  const AdvancedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Advanced')),
      body: EmitterWatcher<Setting>(
        emitter: settingEmitter,
        builder: (context, setting) => ListView(
          children: [
            const ListTile(
              title: Text('FREQUENCY_PENALTY'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model\'s likelihood to repeat the same line verbatim.'),
            ),
            const ListTile(
              title: Text('LOGIT_BIAS'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'Modify the likelihood of specified tokens appearing in the completion.\nAccepts a json object that maps tokens (specified by their token ID in the tokenizer) to an associated bias value from -100 to 100. Mathematically, the bias is added to the logits generated by the model prior to sampling. The exact effect will vary per model, but values between -1 and 1 should decrease or increase likelihood of selection; values like -100 or 100 should result in a ban or exclusive selection of the relevant token.'),
            ),
            const ListTile(
              title: Text('MAX_TOKENS'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'The maximum number of tokens allowed for the generated answer. By default, the number of tokens the model can return will be (4096 - prompt tokens).'),
            ),
            const ListTile(
              title: Text('MODEL'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'ID of the model to use. Currently, only gpt-3.5-turbo and gpt-3.5-turbo-0301 are supported.'),
            ),
            const ListTile(
              title: Text('N'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'How many chat completion choices to generate for each input message.'),
            ),
            const ListTile(
              title: Text('PRESENCE_PENALTY'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model\'s likelihood to talk about new topics.'),
            ),
            const ListTile(
              title: Text('STOP'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'Up to 4 sequences where the API will stop generating further tokens.'),
            ),
            SwitchListTile(
              subtitle: const Text(
                  'If set, partial message deltas will be sent, like in ChatGPT. Tokens will be sent as data-only server-sent events as they become available, with the stream terminated by a data: [DONE] message.'),
              title: const Text('STREAM'),
              value: setting.stream,
              onChanged: (value) => changeStream(context, value),
            ),
            const ListTile(
              title: Text('TEMPERATURE'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.\nWe generally recommend altering this or top_p but not both.'),
            ),
            const ListTile(
              title: Text('TOP_P'),
              trailing: Icon(Icons.chevron_right_outlined),
              subtitle: Text(
                  'An alternative to sampling with temperature, called nucleus sampling, where the model considers the results of the tokens with top_p probability mass. So 0.1 means only the tokens comprising the top 10% probability mass are considered.\nWe generally recommend altering this or temperature but not both.'),
            ),
          ],
        ),
      ),
    );
  }

  void changeStream(BuildContext context, bool value) async {
    try {
      final ref = context.ref;
      final setting = await isar.settings.where().findFirst();
      setting!.stream = value;
      await isar.writeTxn(() async {
        isar.settings.put(setting);
      });
      ref.emit(settingEmitter, setting);
    } catch (error) {
      Logger().e(error);
    }
  }
}