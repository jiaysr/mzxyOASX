import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:oasx/controller/battle/battle_controller.dart';
import 'package:oasx/views/battle/battle_view.dart';

import 'battle_controller_test.dart' show fakeCatalog;

/// 战斗预设页面渲染单测（不联网）
///
/// 只验证「渲染出来、点得动」：预设下拉、技能列表、开关、批量操作入口都在。
/// 排序/禁用的业务逻辑在 battle_controller_test.dart 里测。
void main() {
  late BattleController controller;

  setUp(() {
    controller = BattleController()..autoSave = false;
    controller.applyCatalog(fakeCatalog());
    controller.config.value = 'oas1'; // 不再触发 load
    controller.selectPreset('preset_1'); // 默认编辑系统预设（只读），这里切到可编辑的
    Get.put<BattleController>(controller);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: BattleView())));
    await tester.pump();
  }

  testWidgets('渲染预设栏、技能列表和开关', (tester) async {
    await pumpView(tester);

    expect(find.text('battle_title'), findsOneWidget); // 没有翻译时 .tr 返回 key
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('技能1'), findsOneWidget);
    expect(find.textContaining('我的预设'), findsWidgets); // 预设下拉里的当前预设
    expect(find.byType(Switch), findsAtLeastNWidgets(5));
    expect(find.byType(Checkbox), findsAtLeastNWidgets(5));
    // 战斗设置里：识别相似度 + 四项释放节奏
    expect(find.text('battle_rhythm'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(5));
  });

  testWidgets('关掉一个开关会禁用对应技能', (tester) async {
    await pumpView(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(controller.isDisabled('s1'), isTrue);
    expect(controller.enabledCount, 19);
  });

  testWidgets('勾选两个技能后批量禁用', (tester) async {
    await pumpView(tester);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(controller.selected.length, 2);

    await tester.tap(find.text('battle_batch_disable'));
    await tester.pump();
    expect(controller.enabledCount, 18);
  });

  testWidgets('切到系统预设后是只读的：开关禁用、有系统预设提示', (tester) async {
    controller.selectPreset('default');
    await pumpView(tester);

    final switches = tester
        .widgetList<Switch>(find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Switch),
        ))
        .toList();
    expect(switches.isNotEmpty, isTrue);
    expect(switches.every((widget) => widget.onChanged == null), isTrue,
        reason: '系统预设的技能开关应该禁用');
    expect(find.text('battle_preset_builtin'), findsOneWidget);
    expect(find.text('battle_preset_builtin_hint'), findsOneWidget);
  });
}
