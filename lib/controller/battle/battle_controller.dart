import 'dart:async';

import 'package:get/get.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/model/battle_model.dart';

/// 战斗预设的控制器
///
/// 数据流：
///   GET /battle/catalog -> 技能目录 + 预设列表 + 通用设置
///   页面上改顺序/禁用只改本地（改的是「当前编辑的预设」），防抖 600ms 后
///   PUT /battle/preset 落盘；后台会把归一化后的完整数据再返回一次，用它覆盖本地状态。
///   新建/重命名/删除/切生效预设/恢复默认都是立即调接口（操作语义明确，不适合防抖）。
///
/// 默认预设（builtin=true）在后端是只读的，这里也拦一层：
/// 只读预设上的排序/禁用/恢复默认全部忽略，避免先让用户改了再报错。
class BattleController extends GetxController {
  final config = ''.obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = ''.obs;
  final dirty = false.obs;

  final classes = <BattleClass>[].obs;
  final skills = <BattleSkill>[].obs;
  final presets = <BattlePreset>[].obs;
  final slots = <BattleSlotInfo>[].obs;
  final common = <String, dynamic>{}.obs;
  final defaultOrder = <String>[].obs;

  /// 正在编辑的预设 id
  final editingId = 'default'.obs;

  /// 技能列表里被勾选的技能 id（批量启用/禁用用）
  final selected = <String>[].obs;

  /// 识别结果（/battle/identify 的原样返回）
  final identifyResult = Rxn<Map<String, dynamic>>();
  final identifying = false.obs;

  final threshold = 0.72.obs;
  final castInterval = 0.2.obs;
  final respectCooldown = true.obs;

  Timer? _saveTimer;
  Timer? _commonTimer;
  bool _loading = false;
  int _revision = 0;
  /// 用户是否手动选过预设：没选过时默认跟随「当前生效的预设」
  bool _editingPicked = false;

  /// 是否自动保存（单测里关掉：避免定时器和后台请求）
  bool autoSave = true;

  @override
  void onClose() {
    _saveTimer?.cancel();
    _commonTimer?.cancel();
    super.onClose();
  }

  // ------------------------------------------------------------------ 读取
  Future<void> load(String configName, {bool force = false}) async {
    if (configName.isEmpty || _loading) return;
    if (!force && config.value == configName && skills.isNotEmpty) return;
    _loading = true;
    loading.value = true;
    error.value = '';
    config.value = configName;
    try {
      final json = await ApiClient().getBattleCatalog(configName);
      if (json.isEmpty) {
        error.value = 'battle_load_failed'.tr;
        return;
      }
      applyCatalog(BattleCatalog.fromJson(json));
    } catch (e) {
      error.value = '${'battle_load_failed'.tr}: $e';
    } finally {
      loading.value = false;
      _loading = false;
    }
  }

  /// 用一份目录数据覆盖本地状态（也供单测直接喂数据，不联网）
  void applyCatalog(BattleCatalog catalog) {
    classes.assignAll(catalog.classes);
    skills.assignAll(catalog.skills);
    slots.assignAll(catalog.slots);
    defaultOrder.assignAll(catalog.defaultOrder);
    common.assignAll(catalog.common);

    presets.assignAll(catalog.presets.map((preset) => BattlePreset(
          id: preset.id,
          name: preset.name,
          order: List<String>.of(preset.order),
          disabled: List<String>.of(preset.disabled),
          builtin: preset.builtin,
        )));

    // 正在编辑的预设：用户没手动选过就默认系统预设；选过的预设被删了也要回来
    if (!_editingPicked || _preset(editingId.value) == null) {
      editingId.value =
          _preset('default')?.id ?? (presets.isEmpty ? 'default' : presets.first.id);
    }
    // 勾选里已经不存在的技能清掉
    final ids = skills.map((skill) => skill.id).toSet();
    selected.assignAll(selected.where(ids.contains).toList());

    threshold.value = (common['identify_threshold'] as num?)?.toDouble() ??
        catalog.defaultThreshold;
    castInterval.value = (common['cast_interval'] as num?)?.toDouble() ?? 0.2;
    respectCooldown.value = common['respect_cooldown'] != false;
    dirty.value = false;
  }

  // ------------------------------------------------------------------ 派生
  BattlePreset? _preset(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  BattlePreset? get editingPreset => _preset(editingId.value);

  bool get isReadonly => editingPreset?.builtin ?? true;

  /// 当前预设按顺序排列的技能（包含被禁用的，禁用只在 UI 上灰掉）
  List<BattleSkill> get orderedSkills {
    final preset = editingPreset;
    if (preset == null) return const [];
    final result = <BattleSkill>[];
    for (final id in preset.order) {
      for (final skill in skills) {
        if (skill.id == id) {
          result.add(skill);
          break;
        }
      }
    }
    return result;
  }

  bool isDisabled(String skillId) => editingPreset?.isDisabled(skillId) ?? false;

  bool isEnabled(String skillId) => !isDisabled(skillId);

  int get enabledCount => editingPreset?.enabledCount ?? 0;

  bool isSelected(String skillId) => selected.contains(skillId);

  // ------------------------------------------------------------------ 预设管理
  void selectPreset(String id) {
    if (_preset(id) == null) return;
    _editingPicked = true;
    editingId.value = id;
    selected.clear();
  }

  /// 新建预设（基于 [base] 复制），成功后自动切到新预设
  Future<void> createPreset({String name = '', String base = 'default'}) async {
    if (config.value.isEmpty) return;
    final before = presets.map((preset) => preset.id).toSet();
    final json = await ApiClient().createBattlePreset(config.value,
        name: name, base: base);
    if (json.isEmpty) return;
    applyCatalog(BattleCatalog.fromJson(json));
    for (final preset in presets) {
      if (!before.contains(preset.id)) {
        _editingPicked = true;
        editingId.value = preset.id;
        selected.clear();
        break;
      }
    }
    Get.snackbar('battle_preset_created'.tr, editingPreset?.name ?? '',
        duration: const Duration(seconds: 1));
  }

  Future<void> renamePreset(String name) async {
    final preset = editingPreset;
    if (preset == null || preset.builtin || config.value.isEmpty) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('battle_enter_name'.tr, '', duration: const Duration(seconds: 2));
      return;
    }
    final json = await ApiClient().updateBattlePreset(config.value,
        id: preset.id, name: trimmed);
    if (json.isEmpty) return;
    applyCatalog(BattleCatalog.fromJson(json));
  }

  Future<void> deletePreset() async {
    final preset = editingPreset;
    if (preset == null || preset.builtin || config.value.isEmpty) return;
    final json = await ApiClient().deleteBattlePreset(config.value, preset.id);
    if (json.isEmpty) return;
    // applyCatalog 发现 editingId 不在了会自动落到当前生效的预设
    applyCatalog(BattleCatalog.fromJson(json));
    Get.snackbar('battle_preset_deleted'.tr, '',
        duration: const Duration(seconds: 1));
  }

  /// 当前预设顺序恢复默认、清空禁用
  Future<void> resetOrder() async {
    final preset = editingPreset;
    if (preset == null || preset.builtin || config.value.isEmpty) return;
    _saveTimer?.cancel();
    final json = await ApiClient().resetBattlePreset(config.value, preset.id);
    if (json.isEmpty) return;
    applyCatalog(BattleCatalog.fromJson(json));
    Get.snackbar('battle_reset_done'.tr, '', duration: const Duration(seconds: 1));
  }

  // ------------------------------------------------------------------ 排序
  /// 拖动排序：把 [from] 挪到 [to]（ReorderableListView 的语义）
  void reorder(int from, int to) {
    if (to > from) to -= 1;
    move(from, to);
  }

  /// 把第 [from] 个技能移动到第 [to] 个位置（0 起始）
  void move(int from, int to) {
    final preset = editingPreset;
    if (preset == null || preset.builtin) return;
    final order = preset.order;
    if (from < 0 || from >= order.length) return;
    final target = to.clamp(0, order.length - 1);
    if (from == target) return;
    final list = List<String>.of(order);
    final item = list.removeAt(from);
    list.insert(target, item);
    preset.order = list;
    presets.refresh();
    _scheduleSave();
  }

  void moveUp(int index) => move(index, index - 1);

  void moveDown(int index) => move(index, index + 1);

  void moveTop(int index) => move(index, 0);

  /// 移动到「第 N 位」（1 起始，界面上输入的数字）
  void moveTo(int index, int position) {
    final count = editingPreset?.order.length ?? 0;
    if (count == 0) return;
    final target = (position - 1).clamp(0, count - 1);
    move(index, target);
  }

  // ------------------------------------------------------------------ 启用/禁用
  void toggleSkill(String skillId, bool enabled) {
    final preset = editingPreset;
    if (preset == null || preset.builtin) return;
    final disabled = List<String>.of(preset.disabled);
    if (enabled) {
      disabled.remove(skillId);
    } else if (!disabled.contains(skillId)) {
      disabled.add(skillId);
    }
    preset.disabled = disabled;
    presets.refresh();
    _scheduleSave();
  }

  /// 批量启用/禁用勾选的技能
  void batchSetEnabled(bool enabled) {
    final preset = editingPreset;
    if (preset == null || preset.builtin || selected.isEmpty) return;
    final disabled = List<String>.of(preset.disabled);
    for (final id in selected) {
      if (enabled) {
        disabled.remove(id);
      } else if (!disabled.contains(id)) {
        disabled.add(id);
      }
    }
    preset.disabled = disabled;
    presets.refresh();
    _scheduleSave();
  }

  // ------------------------------------------------------------------ 多选
  void toggleSelect(String skillId, bool value) {
    if (value) {
      if (!selected.contains(skillId)) selected.add(skillId);
    } else {
      selected.remove(skillId);
    }
  }

  void selectAll() {
    selected.assignAll(skills.map((skill) => skill.id).toList());
  }

  void clearSelection() => selected.clear();

  // ------------------------------------------------------------------ 通用设置
  void setThreshold(double value) {
    threshold.value = value;
    common['identify_threshold'] = value;
    _scheduleCommonSave();
  }

  void setCastInterval(double value) {
    castInterval.value = value;
    common['cast_interval'] = value;
    _scheduleCommonSave();
  }

  void setRespectCooldown(bool value) {
    respectCooldown.value = value;
    common['respect_cooldown'] = value;
    _scheduleCommonSave();
  }

  // ------------------------------------------------------------------ 识别
  Future<void> identify() async {
    if (config.value.isEmpty || identifying.value) return;
    identifying.value = true;
    error.value = '';
    try {
      final json = await ApiClient()
          .identifyBattleSlots(config.value, preset: editingId.value);
      identifyResult.value = json;
      if (json['ok'] != true) {
        final message = json['message']?.toString() ?? 'battle_identify_failed'.tr;
        Get.snackbar('battle_identify_failed'.tr, message,
            duration: const Duration(seconds: 4));
      }
    } catch (e) {
      error.value = '${'battle_identify_failed'.tr}: $e';
    } finally {
      identifying.value = false;
    }
  }

  // ------------------------------------------------------------------ 保存
  void _scheduleSave() {
    if (isReadonly || !autoSave) return;
    _revision++;
    dirty.value = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _savePreset);
  }

  Future<void> _savePreset() async {
    final preset = editingPreset;
    if (config.value.isEmpty || preset == null || preset.builtin) return;
    final revision = _revision;
    saving.value = true;
    try {
      final json = await ApiClient().updateBattlePreset(config.value,
          id: preset.id, order: preset.order, disabled: preset.disabled);
      if (json.isNotEmpty) {
        applyCatalog(BattleCatalog.fromJson(json));
      }
      dirty.value = _revision != revision;
    } finally {
      saving.value = false;
    }
  }

  void _scheduleCommonSave() {
    if (!autoSave) return;
    _commonTimer?.cancel();
    _commonTimer = Timer(const Duration(milliseconds: 500), _saveCommon);
  }

  Future<void> _saveCommon() async {
    if (config.value.isEmpty) return;
    saving.value = true;
    try {
      final json = await ApiClient().setBattleCommon(config.value, {
        'identify_threshold': threshold.value,
        'cast_interval': castInterval.value,
        'respect_cooldown': respectCooldown.value,
      });
      if (json.isNotEmpty) {
        applyCatalog(BattleCatalog.fromJson(json));
      }
    } finally {
      saving.value = false;
    }
  }
}
