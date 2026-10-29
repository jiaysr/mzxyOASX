import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/controller/battle/battle_controller.dart';
import 'package:oasx/model/battle_model.dart';
import 'package:oasx/views/nav/view_nav.dart';

/// 战斗预设页面（脚本 -> 战斗）
///
/// 内容：
/// - 预设管理：默认预设（系统，只读）+ 用户预设（可新建/重命名/删除/设为当前）；
///   新建时可以选择「基于哪个预设」，复制它的顺序和禁用；
/// - 技能顺序：每个预设都包含全部 20 个技能，用「上移/下移/置顶/移动到第 N 位」
///   调整优先级（比拖 20 项顺手），每行一个启用开关；
/// - 多选：勾选若干技能后可以批量启用/禁用；
/// - 设置：识别阈值 / 是否只点冷却好的 / 点击间隔；
/// - 识别结果：开战前技能位识别 + 算出来的释放顺序（和任务里跑的是同一套代码）。
///
/// 开战前识别技能栏是固定行为，没有开关。
class BattleView extends StatelessWidget {
  const BattleView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<BattleController>(builder: (controller) {
      _ensureLoaded(controller, _selectedScript());

      if (controller.loading.value && controller.skills.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, controller),
            if (controller.error.value.isNotEmpty) _errorBanner(context, controller),
            if (controller.skills.isEmpty)
              _empty(context)
            else ...[
              _presetBar(context, controller),
              _skillCard(context, controller),
              _settingsCard(context, controller),
              _identifyCard(context, controller),
            ],
          ],
        ).constrained(maxWidth: 980),
      ).alignment(Alignment.topCenter);
    });
  }

  String _selectedScript() {
    if (!Get.isRegistered<NavCtrl>()) return '';
    return Get.find<NavCtrl>().selectedScript.value;
  }

  void _ensureLoaded(BattleController controller, String script) {
    if (script.isEmpty || script == controller.config.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.load(script));
  }

  // ------------------------------------------------------------------ 顶部
  Widget _header(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('battle_title'.tr, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'battle_priority_hint'.tr,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (controller.saving.value)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (controller.dirty.value && !controller.saving.value)
            Text('battle_unsaved'.tr,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }

  Widget _errorBanner(BuildContext context, BattleController controller) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(controller.error.value,
          style: TextStyle(color: scheme.onErrorContainer)),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text('battle_empty_skills'.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  // ------------------------------------------------------------------ 预设栏
  Widget _presetBar(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final preset = controller.editingPreset;
    final readonly = controller.isReadonly;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('battle_presets'.tr, style: theme.textTheme.titleMedium),
                const SizedBox(width: 12),
                if (readonly)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.lock, size: 14),
                    label: Text('battle_preset_builtin'.tr),
                  ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _showNewPresetDialog(context, controller),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('battle_preset_new'.tr),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: preset?.id,
                  underline: const SizedBox.shrink(),
                  items: controller.presets
                      .map((item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.selectPreset(value);
                  },
                ),
                TextButton.icon(
                  onPressed: readonly || preset == null
                      ? null
                      : () => _showRenameDialog(context, controller, preset.name),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('battle_preset_rename'.tr),
                ),
                TextButton.icon(
                  onPressed: readonly || preset == null
                      ? null
                      : () => _confirmDeletePreset(context, controller),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text('battle_preset_delete'.tr),
                ),
              ],
            ),
            if (readonly) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'battle_preset_builtin_hint'.tr,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showNewPresetDialog(context, controller,
                        base: preset?.id ?? 'default'),
                    child: Text('battle_preset_new'.tr),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 技能列表
  Widget _skillCard(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final skills = controller.orderedSkills;
    final readonly = controller.isReadonly;
    final hasSelection = controller.selected.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('battle_skills'.tr, style: theme.textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Text(
                      '${'battle_enabled_count'.tr} ${controller.enabledCount}/${skills.length}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: readonly ? null : controller.resetOrder,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text('battle_reset_default'.tr),
                    ),
                  ],
                ),
                if (!readonly)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        hasSelection
                            ? 'battle_selected'.tr.replaceAll(
                                '%d', '${controller.selected.length}')
                            : '',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                      TextButton(
                        onPressed: hasSelection
                            ? controller.clearSelection
                            : controller.selectAll,
                        child: Text(hasSelection
                            ? 'battle_select_none'.tr
                            : 'battle_select_all'.tr),
                      ),
                      if (hasSelection) ...[
                        FilledButton.tonal(
                          onPressed: () => controller.batchSetEnabled(true),
                          child: Text('battle_batch_enable'.tr),
                        ),
                        FilledButton.tonal(
                          onPressed: () => controller.batchSetEnabled(false),
                          child: Text('battle_batch_disable'.tr),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: _listHeight(context),
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: skills.length,
              onReorder: controller.reorder,
              itemBuilder: (context, index) => _skillTile(
                context,
                controller,
                skills[index],
                index,
                readonly: readonly,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _listHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return (screenHeight * 0.52).clamp(280.0, 620.0);
  }

  Widget _skillTile(BuildContext context, BattleController controller,
      BattleSkill skill, int index, {required bool readonly}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = controller.isDisabled(skill.id);
    final compact = MediaQuery.of(context).size.width < 720;

    return Container(
      key: ValueKey(skill.id),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: controller.isSelected(skill.id),
              onChanged: readonly
                  ? null
                  : (value) =>
                      controller.toggleSelect(skill.id, value ?? false),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            enabled: !readonly,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.drag_indicator,
                  size: 20,
                  color: (disabled || readonly)
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                      : scheme.onSurfaceVariant),
            ),
          ),
          _indexChip(context, controller, index, readonly),
          const SizedBox(width: 4),
          Opacity(opacity: disabled ? 0.45 : 1, child: _skillIcon(context, skill)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        skill.name.tr,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: disabled ? scheme.onSurfaceVariant : null,
                          decoration:
                              disabled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _classTag(context, skill, disabled),
                  ],
                ),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      skill.description.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                              alpha: disabled ? 0.5 : 1)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'battle_move_up'.tr,
            visualDensity: VisualDensity.compact,
            onPressed:
                readonly || index == 0 ? null : () => controller.moveUp(index),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: 'battle_move_down'.tr,
            visualDensity: VisualDensity.compact,
            onPressed: readonly || index >= controller.orderedSkills.length - 1
                ? null
                : () => controller.moveDown(index),
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
          Tooltip(
            message: 'battle_skill_disabled'.tr,
            child: Switch(
              value: !disabled,
              onChanged: readonly
                  ? null
                  : (value) => controller.toggleSkill(skill.id, value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indexChip(BuildContext context, BattleController controller,
      int index, bool readonly) {
    final theme = Theme.of(context);
    final enabled = !readonly;
    return Tooltip(
      message: 'battle_move_to'.tr,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled
            ? () => _showMoveToDialog(context, controller, index)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _skillIcon(BuildContext context, BattleSkill skill) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        skill.name.isNotEmpty ? skill.name.substring(0, 1) : '?',
        style: theme.textTheme.titleMedium,
      ),
    );
    if (skill.iconUrl.isEmpty) return fallback;
    final url = ApiClient().battleIconUrl(skill.iconUrl);
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  Widget _classTag(BuildContext context, BattleSkill skill, bool disabled) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer
            .withValues(alpha: disabled ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        skill.className.tr,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }

  // ------------------------------------------------------------------ 设置
  Widget _settingsCard(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Icon(Icons.settings_suggest, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('battle_settings'.tr, style: theme.textTheme.titleMedium),
            ]),
          ),
          SwitchListTile(
            dense: true,
            value: controller.respectCooldown.value,
            onChanged: controller.setRespectCooldown,
            title: Text('battle_respect_cooldown'.tr),
          ),
          _sliderTile(
            context,
            title: 'battle_similarity'.tr,
            help: 'battle_similarity_help'.tr,
            value: controller.threshold.value,
            min: 0.4,
            max: 0.95,
            divisions: 11,
            label: controller.threshold.value.toStringAsFixed(2),
            onChanged: controller.setThreshold,
          ),
          _sliderTile(
            context,
            title: 'battle_cast_interval'.tr,
            value: controller.castInterval.value,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${controller.castInterval.value.toStringAsFixed(2)} s',
            onChanged: controller.setCastInterval,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sliderTile(
    BuildContext context, {
    required String title,
    String? help,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium),
                    if (help != null && help.isNotEmpty)
                      Text(help,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 识别
  Widget _identifyCard(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final result = controller.identifyResult.value;
    final plan = ((result?['plan'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final slots = ((result?['slots'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.center_focus_strong,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('battle_identify_result'.tr,
                      style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.identifying.value
                      ? null
                      : controller.identify,
                  icon: controller.identifying.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility, size: 18),
                  label: Text(controller.identifying.value
                      ? 'battle_identifying'.tr
                      : 'battle_identify'.tr),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result == null)
              Text('battle_identify_empty'.tr,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else if (result['ok'] != true)
              Text('${result['message'] ?? 'battle_identify_failed'.tr}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error))
            else ...[
              Text('battle_plan_preview'.tr,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < plan.length; i++)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '#${i + 1} ${plan[i]['slotName'] ?? ''} · '
                        '${(plan[i]['recognized'] == true) ? (plan[i]['name'] ?? '') : 'battle_unknown_skill'.tr}',
                      ),
                    ),
                  if (plan.isEmpty) Text('—', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 12),
              Text('battle_identify_result'.tr,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final slot in slots)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: slot['skill'] == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                      label: Text(
                        '${slot['slotName'] ?? ''}: '
                        '${slot['skill'] == null ? 'battle_unknown_skill'.tr : slot['name']} '
                        '(${((slot['score'] as num?) ?? 0).toStringAsFixed(2)})',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 弹窗
  Future<void> _showNewPresetDialog(BuildContext context,
      BattleController controller,
      {String base = 'default'}) async {
    var selectedBase = base;
    final nameController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('battle_preset_new_title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'battle_preset_name'.tr,
                  hintText: 'battle_preset_name_hint'.tr,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBase,
                decoration: InputDecoration(labelText: 'battle_preset_base'.tr),
                items: controller.presets
                    .map((preset) => DropdownMenuItem<String>(
                          value: preset.id,
                          child: Text(preset.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedBase = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'.tr)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Confirm'.tr)),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (created == true) {
      await controller.createPreset(name: name, base: selectedBase);
    }
  }

  Future<void> _showRenameDialog(BuildContext context,
      BattleController controller, String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('battle_preset_rename_title'.tr),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: 'battle_preset_name'.tr),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'.tr)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirm'.tr)),
        ],
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (renamed == true) {
      await controller.renamePreset(name);
    }
  }

  Future<void> _confirmDeletePreset(
      BuildContext context, BattleController controller) async {
    final preset = controller.editingPreset;
    if (preset == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('battle_preset_delete_title'.tr),
        content: Text('${'battle_preset_delete_confirm'.tr}\n${preset.name}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'.tr)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete'.tr)),
        ],
      ),
    );
    if (ok == true) {
      await controller.deletePreset();
    }
  }

  Future<void> _showMoveToDialog(
      BuildContext context, BattleController controller, int index) async {
    final textController = TextEditingController(text: '${index + 1}');
    final total = controller.orderedSkills.length;
    final moved = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('battle_move_to_title'.tr),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'battle_move_to_hint'.tr
                .replaceAll('%d', '$total'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('Cancel'.tr)),
          FilledButton(
              onPressed: () {
                final value = int.tryParse(textController.text.trim());
                Navigator.pop(ctx, value);
              },
              child: Text('Confirm'.tr)),
        ],
      ),
    );
    textController.dispose();
    if (moved != null) {
      controller.moveTo(index, moved);
    }
  }
}

extension _BattleViewPart on Widget {
  Widget constrained({required double maxWidth}) =>
      ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: this);

  Widget alignment(Alignment alignment) =>
      Align(alignment: alignment, child: this);
}
