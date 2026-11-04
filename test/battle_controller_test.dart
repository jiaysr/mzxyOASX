import 'package:flutter_test/flutter_test.dart';

import 'package:oasx/controller/battle/battle_controller.dart';
import 'package:oasx/model/battle_model.dart';

/// 战斗预设的本地逻辑单测（不联网、不需要后台）
///
/// 覆盖：预设落地（默认编辑系统预设）、排序（上移/下移/置顶/移动到第 N 位）、
/// 禁用、多选批量启用禁用、系统预设只读、预设之间互不影响。
BattleCatalog fakeCatalog({int skillCount = 20}) {
  final skills = <BattleSkill>[
    for (int i = 1; i <= skillCount; i++)
      BattleSkill(
        id: 's$i',
        classId: 'c${(i + 3) ~/ 4}',
        className: '职业${(i + 3) ~/ 4}',
        name: '技能$i',
        description: '占位描述$i',
        // 默认留空：单测不碰网络（页面会退回文字占位图标）
        iconUrl: '',
        defaultPriority: i,
      ),
  ];
  final order = skills.map((s) => s.id).toList();
  return BattleCatalog(
    config: 'oas1',
    classes: const [
      BattleClass(id: 'c1', name: '职业1'),
      BattleClass(id: 'c2', name: '职业2'),
      BattleClass(id: 'c3', name: '职业3'),
      BattleClass(id: 'c4', name: '职业4'),
      BattleClass(id: 'c5', name: '职业5'),
    ],
    skills: skills,
    presets: [
      BattlePreset(
        id: 'default',
        name: '默认预设',
        order: List.of(order),
        builtin: true,
      ),
      BattlePreset(id: 'preset_1', name: '我的预设', order: List.of(order)),
    ],
    slots: const [
      BattleSlotInfo(index: 0, name: '技能1', region: [991, 582, 52, 54]),
      BattleSlotInfo(index: 1, name: '技能2', region: [1033, 484, 52, 54]),
    ],
    common: {
      'identify_threshold': 0.72,
      'respect_cooldown': true,
      'cast_interval': 0.2,
    },
    defaultOrder: List.of(order),
    defaultThreshold: 0.72,
  );
}

List<String> ids(BattleController controller) =>
    controller.orderedSkills.map((skill) => skill.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BattleController controller;

  setUp(() {
    controller = BattleController()..autoSave = false;
    controller.applyCatalog(fakeCatalog());
  });

  tearDown(() {
    controller.onClose();
  });

  /// 切到可编辑的「我的预设」
  void editUserPreset() => controller.selectPreset('preset_1');

  test('预设落地：默认看系统预设（只读），列表里有系统预设 + 用户预设', () {
    expect(controller.presets.length, 2);
    expect(controller.editingId.value, 'default');
    expect(controller.isReadonly, isTrue);    expect(controller.orderedSkills.length, 20);

    editUserPreset();
    expect(controller.isReadonly, isFalse);
    expect(controller.enabledCount, 20);
  });

  test('排序：上移 / 下移 / 置顶 / 移动到第 N 位', () {
    editUserPreset();
    controller.moveDown(0);
    expect(ids(controller).take(2).toList(), ['s2', 's1']);

    controller.moveUp(1);
    expect(ids(controller).take(2).toList(), ['s1', 's2']);

    controller.moveTop(19);
    expect(ids(controller).first, 's20');
    expect(ids(controller).length, 20, reason: '排序不能丢技能');

    // 界面上的「移动到第 3 位」= 下标 2
    controller.moveTo(0, 3);
    expect(ids(controller).indexOf('s20'), 2);
  });

  test('拖拽排序语义：reorder(0, 3) 等于放到第 3 个位置', () {
    editUserPreset();
    controller.reorder(0, 3);
    expect(ids(controller).take(3).toList(), ['s2', 's3', 's1']);
  });

  test('禁用：禁用的技能留在顺序里，只是不算启用', () {
    editUserPreset();
    controller.toggleSkill('s5', false);
    expect(controller.isDisabled('s5'), isTrue);
    expect(controller.enabledCount, 19);
    expect(ids(controller).indexOf('s5'), 4, reason: '禁用后位置要保留');

    controller.toggleSkill('s5', true);
    expect(controller.isDisabled('s5'), isFalse);
    expect(controller.isEnabled('s5'), isTrue);
  });

  test('多选 + 批量禁用/启用', () {
    editUserPreset();
    controller.selectAll();
    expect(controller.selected.length, 20);

    controller.clearSelection();
    controller.toggleSelect('s1', true);
    controller.toggleSelect('s2', true);
    controller.toggleSelect('s3', true);
    expect(controller.selected.length, 3);

    controller.batchSetEnabled(false);
    expect(controller.enabledCount, 17);
    expect(controller.isDisabled('s1'), isTrue);

    controller.batchSetEnabled(true);
    expect(controller.enabledCount, 20);
  });

  test('系统预设只读：排序和禁用全部被忽略', () {
    expect(controller.editingId.value, 'default');
    expect(controller.isReadonly, isTrue);

    controller.moveTop(19);
    controller.toggleSkill('s1', false);
    controller.selectAll();
    controller.batchSetEnabled(false);

    expect(ids(controller).first, 's1');
    expect(controller.enabledCount, 20);
    expect(controller.isDisabled('s1'), isFalse);
  });

  test('预设之间互相独立', () {
    editUserPreset();
    controller.toggleSkill('s1', false);
    controller.moveTop(19);
    expect(controller.isDisabled('s1'), isTrue);

    controller.selectPreset('default');
    expect(controller.isDisabled('s1'), isFalse);
    expect(ids(controller).first, 's1');

    controller.selectPreset('preset_1');
    expect(controller.isDisabled('s1'), isTrue);
    expect(ids(controller).first, 's20');
  });

  test('通用设置同步到 common', () {
    controller.setThreshold(0.85);
    expect(controller.common['identify_threshold'], 0.85);
    expect(controller.threshold.value, 0.85);
  });

  test('applyCatalog：正在编辑的预设没了就回到系统预设', () {
    editUserPreset();
    final catalog = fakeCatalog();
    catalog.presets.removeWhere((preset) => preset.id == 'preset_1');
    controller.applyCatalog(catalog);
    expect(controller.presets.length, 1);
    expect(controller.editingId.value, 'default');
  });

  test('释放节奏：四项挂在当前编辑的预设上，越界自动夹住，系统预设只读', () {
    editUserPreset();
    expect(controller.clicks, 2);
    expect(controller.clickInterval, 0.2);
    expect(controller.attempts, 3);
    expect(controller.cooldownTimeout, 1.2);

    controller.setClicks(4);
    controller.setClickInterval(0.35);
    controller.setAttempts(1);
    controller.setCooldownTimeout(0.6);
    expect(controller.clicks, 4);
    expect(controller.clickInterval, 0.35);
    expect(controller.attempts, 1);
    expect(controller.cooldownTimeout, 0.6);
    expect(controller.editingPreset!.clicks, 4);
    expect(controller.editingPreset!.cooldownTimeout, 0.6);

    // 越界夹到边界（和后端 BattlePreset 的 ge/le 一致）
    controller.setClicks(9);
    controller.setAttempts(0);
    controller.setClickInterval(5);
    controller.setCooldownTimeout(3);
    expect(controller.clicks, 4);
    expect(controller.attempts, 1);
    expect(controller.clickInterval, 1.0);
    expect(controller.cooldownTimeout, 2.0);

    // 每个预设各一份：切到另一个预设看的是它自己的值
    controller.selectPreset('default');
    expect(controller.clicks, 2);
    controller.selectPreset('preset_1');
    expect(controller.clicks, 4);

    // 系统预设只读：改了也不生效
    controller.selectPreset('default');
    controller.setClicks(1);
    expect(controller.clicks, 2);
  });
}
