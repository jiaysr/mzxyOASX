import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:oasx/views/args/args_view.dart';

void main() {
  test('Counter value should be incremented', () {
    ArgsTest argsTest = ArgsTest();
    argsTest.testArgsView();

    // expect(argsTest.testArgsView, 1);
  });

  test('world boss dual fields visible only with two same-time bosses', () {
    final controller = ArgsController();
    final wuqing19 = ArgumentModel(null, null, null, null, null,
        title: 'time_19', value: true, type: 'boolean');
    final julian19 = ArgumentModel(null, null, null, null, null,
        title: 'time_19', value: true, type: 'boolean');
    final wuqing18 = ArgumentModel(null, null, null, null, null,
        title: 'time_18', value: false, type: 'boolean');
    controller.groupsData.value = {
      'wuqing': GroupsModel(groupName: 'wuqing', members: [wuqing19, wuqing18]),
      'julian': GroupsModel(groupName: 'julian', members: [julian19]),
    };
    final field = ArgumentModel(null, null, null, null, null,
        title: 'first_boss',
        value: 'auto',
        type: 'enum',
        visibleWhen: 'world_boss_dual');

    expect(controller.isVisible(field), isTrue);

    julian19.value = false;
    expect(controller.isVisible(field), isFalse);
  });
}

class ArgsTest {
  void testArgsView() {
    File jsonFile = File(
        '${Directory.current.path}\\lib\\controller\\args\\task.json'); // 替换为您的 JSON 文件路径
    String jsonString = jsonFile.readAsStringSync();
    ArgsController c = ArgsController();
    c.loadModelfromStr(jsonString);
  }
}
