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

  static const double _maxWidth = 980;
  static const double _panelGap = 16;

  @override
  Widget build(BuildContext context) {
    return GetX<BattleController>(builder: (controller) {
      _ensureLoaded(controller, _selectedScript());

      if (controller.loading.value && controller.skills.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, controller),
            if (controller.error.value.isNotEmpty)
              _errorBanner(context, controller),
            if (controller.skills.isEmpty)
              _empty(context)
            else ...[
              _presetPanel(context, controller),
              _skillsPanel(context, controller),
              _settingsPanel(context, controller),
              _identifyPanel(context, controller),
            ],
          ],
        ).constrained(maxWidth: _maxWidth),
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
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _panelGap),
      child: Row(
        children: [
          _iconBadge(context, Icons.bolt_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'battle_title'.tr,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'battle_priority_hint'.tr,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _saveStatus(context, controller),
        ],
      ),
    );
  }

  Widget _saveStatus(BuildContext context, BattleController controller) {
    final scheme = Theme.of(context).colorScheme;
    if (controller.saving.value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!controller.dirty.value) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'battle_unsaved'.tr,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(BuildContext context, BattleController controller) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: _panelGap),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.error.value,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'battle_empty_skills'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 面板骨架
  Widget _panel(
    BuildContext context, {
    required Widget header,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: _panelGap),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _panelHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: LayoutBuilder(builder: (context, constraints) {
        // 窄屏（或长词条语言）下操作区换到第二行，避免标题和按钮互相挤
        final stack = trailing != null && constraints.maxWidth < 360;
        final titleRow = Row(
          children: [
            _iconBadge(context, icon, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: titleStyle)),
            if (trailing != null && !stack) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        );
        if (!stack) return titleRow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleRow,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        );
      }),
    );
  }

  Widget _iconBadge(BuildContext context, IconData icon, {double size = 32}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: scheme.primary),
    );
  }

  // ------------------------------------------------------------------ 预设栏
  Widget _presetPanel(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preset = controller.editingPreset;
    final readonly = controller.isReadonly;

    return _panel(
      context,
      header: _panelHeader(
        context,
        icon: Icons.tune_rounded,
        title: 'battle_presets'.tr,
        trailing: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => _showNewPresetDialog(context, controller),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('battle_preset_new'.tr),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final selector = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'battle_preset'.tr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: preset?.id,
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        icon: Icon(Icons.expand_more_rounded,
                            color: scheme.onSurfaceVariant),
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
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: readonly || preset == null
                          ? null
                          : () => _showRenameDialog(
                              context, controller, preset.name),
                      icon: const Icon(Icons.drive_file_rename_outline_rounded,
                          size: 18),
                      label: Text('battle_preset_rename'.tr),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: scheme.error,
                      ),
                      onPressed: readonly || preset == null
                          ? null
                          : () => _confirmDeletePreset(context, controller),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('battle_preset_delete'.tr),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      selector,
                      const SizedBox(height: 4),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: selector),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              }),
            ),
            if (readonly) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.lock_outline_rounded,
                              size: 14),
                          label: Text('battle_preset_builtin'.tr),
                          side:
                              BorderSide(color: scheme.outlineVariant),
                          backgroundColor: Colors.transparent,
                        ),
                        TextButton(
                          onPressed: () => _showNewPresetDialog(
                              context, controller,
                              base: preset?.id ?? 'default'),
                          child: Text('battle_preset_new'.tr),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 8),
                      child: Text(
                        'battle_preset_builtin_hint'.tr,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 技能列表
  Widget _skillsPanel(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skills = controller.orderedSkills;
    final readonly = controller.isReadonly;
    final hasSelection = controller.selected.isNotEmpty;
    final narrowHeader = MediaQuery.of(context).size.width < 560;

    return _panel(
      context,
      header: _panelHeader(
        context,
        icon: Icons.bolt_rounded,
        title: 'battle_skills'.tr,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!narrowHeader)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${'battle_enabled_count'.tr} ${controller.enabledCount}/${skills.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!narrowHeader) const SizedBox(width: 4),
            if (narrowHeader)
              IconButton(
                tooltip: 'battle_reset_default'.tr,
                onPressed: readonly ? null : controller.resetOrder,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
              )
            else
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: readonly ? null : controller.resetOrder,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text('battle_reset_default'.tr),
              ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!readonly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: hasSelection
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'battle_selected'.tr.replaceAll(
                                    '%d', '${controller.selected.length}'),
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: controller.clearSelection,
                            child: Text('battle_select_none'.tr),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => controller.batchSetEnabled(true),
                            child: Text('battle_batch_enable'.tr),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => controller.batchSetEnabled(false),
                            child: Text('battle_batch_disable'.tr),
                          ),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: controller.selectAll,
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: Text('battle_select_all'.tr),
                      ),
                    ),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
        ],
      ),
    );
  }

  Widget _skillTile(BuildContext context, BattleController controller,
      BattleSkill skill, int index, {required bool readonly}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = controller.isDisabled(skill.id);
    final width = MediaQuery.of(context).size.width;
    final compact = width < 720;
    final narrow = width < 560;

    return _HoverRow(
      key: ValueKey(skill.id),
      hoverColor: scheme.primary.withValues(alpha: 0.04),
      background:
          disabled ? scheme.surfaceContainerHighest.withValues(alpha: 0.35) : null,
      border: Border(
        bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                visualDensity: VisualDensity.compact,
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
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: (disabled || readonly)
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            _priorityBadge(context, controller, index,
                readonly: readonly, disabled: disabled),
            const SizedBox(width: 10),
            Opacity(
              opacity: disabled ? 0.45 : 1,
              child: _skillIcon(context, skill),
            ),
            const SizedBox(width: 12),
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
                            fontWeight: FontWeight.w600,
                            color: disabled ? scheme.onSurfaceVariant : null,
                            decoration: disabled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 8),
                        _classTag(context, controller, skill, disabled),
                      ],
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
                              alpha: disabled ? 0.5 : 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!narrow)
              _reorderCluster(context, controller, index,
                  readonly: readonly, disabled: disabled),
            const SizedBox(width: 4),
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
      ),
    );
  }

  Widget _priorityBadge(BuildContext context, BattleController controller,
      int index, {required bool readonly, required bool disabled}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTop = index < 3;
    final background = isTop
        ? scheme.primary.withValues(alpha: disabled ? 0.4 : 1)
        : scheme.surfaceContainerHighest.withValues(alpha: disabled ? 0.4 : 0.9);
    final foreground = isTop ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Tooltip(
      message: 'battle_move_to'.tr,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            readonly ? null : () => _showMoveToDialog(context, controller, index),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _reorderCluster(BuildContext context, BattleController controller,
      int index, {required bool readonly, required bool disabled}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniIconButton(
            icon: Icons.keyboard_arrow_up_rounded,
            tooltip: 'battle_move_up'.tr,
            onPressed: readonly || index == 0
                ? null
                : () => controller.moveUp(index),
          ),
          Container(
            width: 1,
            height: 16,
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
          _miniIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'battle_move_down'.tr,
            onPressed: readonly || index >= controller.orderedSkills.length - 1
                ? null
                : () => controller.moveDown(index),
          ),
        ],
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      icon: Icon(icon, size: 18),
    );
  }

  Widget _skillIcon(BuildContext context, BattleSkill skill) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  Widget _classTag(BuildContext context, BattleController controller,
      BattleSkill skill, bool disabled) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _classColor(controller, skill) ??
        (disabled ? scheme.onSurfaceVariant : scheme.secondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: disabled ? 0.4 : 1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            skill.className.tr,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Color? _classColor(BattleController controller, BattleSkill skill) {
    for (final item in controller.classes) {
      if (item.id != skill.classId) continue;
      final hex = item.color.replaceFirst('#', '');
      final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }

  // ------------------------------------------------------------------ 设置
  Widget _settingsPanel(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _panel(
      context,
      header: _panelHeader(
        context,
        icon: Icons.settings_suggest_rounded,
        title: 'battle_settings'.tr,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 固定行为：显示出来但禁止修改（灰色样式）
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.timer_outlined,
                  color: scheme.onSurfaceVariant, size: 22),
              value: true,
              onChanged: null,
              title: Text(
                'battle_respect_cooldown'.tr,
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text(
                'battle_respect_cooldown_fixed'.tr,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final similarity = _sliderTile(
                context,
                title: 'battle_similarity'.tr,
                help: 'battle_similarity_help'.tr,
                value: controller.threshold.value,
                min: 0.4,
                max: 0.95,
                divisions: 11,
                label: controller.threshold.value.toStringAsFixed(2),
                minLabel: '0.40',
                maxLabel: '0.95',
                onChanged: controller.setThreshold,
              );
              // 旧路径遗留项：固定 0.20 s，显示但禁止修改
              final legacy = _sliderTile(
                context,
                title: 'battle_cast_interval'.tr,
                help: 'battle_cast_interval_fixed'.tr,
                value: 0.2,
                min: 0,
                max: 1,
                divisions: 20,
                label: '0.20 s',
                minLabel: '0 s',
                maxLabel: '1.00 s',
                onChanged: null,
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    similarity,
                    const SizedBox(height: 12),
                    legacy,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: similarity),
                  const SizedBox(width: 32),
                  Expanded(child: legacy),
                ],
              );
            }),
            const Divider(height: 28),
            // 释放节奏：全局唯一（不跟预设走），所有任务共用一套
            Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'battle_rhythm'.tr,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'battle_rhythm_help'.tr,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              // 释放节奏挂在当前编辑的预设上：系统预设只读，滑块禁用
              final presetReadonly = controller.isReadonly;
              final clicks = _sliderTile(
                context,
                title: 'battle_clicks'.tr,
                help: 'battle_clicks_help'.tr,
                value: controller.clicks.toDouble(),
                min: 1,
                max: 4,
                divisions: 3,
                label: '${controller.clicks}',
                minLabel: '1',
                maxLabel: '4',
                onChanged: presetReadonly
                    ? null
                    : (value) => controller.setClicks(value.round()),
              );
              final interval = _sliderTile(
                context,
                title: 'battle_click_interval'.tr,
                help: 'battle_click_interval_help'.tr,
                value: controller.clickInterval,
                min: 0.05,
                max: 1,
                divisions: 19,
                label: '${controller.clickInterval.toStringAsFixed(2)} s',
                minLabel: '0.05 s',
                maxLabel: '1.00 s',
                onChanged:
                    presetReadonly ? null : controller.setClickInterval,
              );
              final attempts = _sliderTile(
                context,
                title: 'battle_attempts'.tr,
                help: 'battle_attempts_help'.tr,
                value: controller.attempts.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '${controller.attempts}',
                minLabel: '1',
                maxLabel: '5',
                onChanged: presetReadonly
                    ? null
                    : (value) => controller.setAttempts(value.round()),
              );
              final cooldown = _sliderTile(
                context,
                title: 'battle_cooldown_timeout'.tr,
                help: 'battle_cooldown_timeout_help'.tr,
                value: controller.cooldownTimeout,
                min: 0.2,
                max: 2,
                divisions: 18,
                label: '${controller.cooldownTimeout.toStringAsFixed(2)} s',
                minLabel: '0.2 s',
                maxLabel: '2.00 s',
                onChanged:
                    presetReadonly ? null : controller.setCooldownTimeout,
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    clicks,
                    const SizedBox(height: 8),
                    interval,
                    const SizedBox(height: 8),
                    attempts,
                    const SizedBox(height: 8),
                    cooldown,
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: clicks),
                      const SizedBox(width: 32),
                      Expanded(child: interval),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: attempts),
                      const SizedBox(width: 32),
                      Expanded(child: cooldown),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
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
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double>? onChanged,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (help != null && help.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        help,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                maxLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ 识别
  Widget _identifyPanel(BuildContext context, BattleController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = controller.identifyResult.value;
    final plan = ((result?['plan'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final slots = ((result?['slots'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    return _panel(
      context,
      header: _panelHeader(
        context,
        icon: Icons.center_focus_strong_rounded,
        title: 'battle_identify_result'.tr,
        trailing: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
          onPressed: controller.identifying.value ? null : controller.identify,
          icon: controller.identifying.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_rounded, size: 18),
          label: Text(controller.identifying.value
              ? 'battle_identifying'.tr
              : 'battle_identify'.tr),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: result == null
            ? _hintBox(
                context,
                icon: Icons.info_outline_rounded,
                text: 'battle_identify_empty'.tr,
              )
            : result['ok'] != true
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 18, color: scheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${result['message'] ?? 'battle_identify_failed'.tr}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionLabel(context, 'battle_plan_preview'.tr),
                      if (plan.isEmpty)
                        Text('—', style: theme.textTheme.bodyMedium)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < plan.length; i++)
                              _planChip(context, i, plan[i]),
                          ],
                        ),
                      const SizedBox(height: 18),
                      _sectionLabel(context, 'battle_identify_result'.tr),
                      if (slots.isEmpty)
                        Text('—', style: theme.textTheme.bodyMedium)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in slots)
                              _slotCard(context, slot),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _hintBox(BuildContext context,
      {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _planChip(BuildContext context, int index, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recognized = item['recognized'] == true;
    final name = recognized
        ? (item['name'] ?? '').toString()
        : 'battle_unknown_skill'.tr;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: recognized
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: recognized
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: recognized ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (item['slotName'] ?? '').toString(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: recognized ? FontWeight.w500 : FontWeight.w400,
              color: recognized ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(BuildContext context, Map<String, dynamic> slot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recognized = slot['skill'] != null;
    final score = ((slot['score'] as num?) ?? 0).toStringAsFixed(2);
    return Container(
      width: 208,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: recognized
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: recognized
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              recognized ? Icons.check_rounded : Icons.help_outline_rounded,
              size: 16,
              color: recognized ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (slot['slotName'] ?? '').toString(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 1),
                Text(
                  recognized
                      ? (slot['name'] ?? '').toString()
                      : 'battle_unknown_skill'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: recognized
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            score,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
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

/// 技能行的悬停底色（桌面端扫列表时给一点位置感）
class _HoverRow extends StatefulWidget {
  const _HoverRow({
    super.key,
    required this.child,
    required this.hoverColor,
    this.background,
    this.border,
  });

  final Widget child;
  final Color hoverColor;
  final Color? background;
  final BoxBorder? border;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.background ??
              (_hovered ? widget.hoverColor : Colors.transparent),
          border: widget.border,
        ),
        child: widget.child,
      ),
    );
  }
}

extension _BattleViewPart on Widget {
  Widget constrained({required double maxWidth}) =>
      ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: this);

  Widget alignment(Alignment alignment) =>
      Align(alignment: alignment, child: this);
}
