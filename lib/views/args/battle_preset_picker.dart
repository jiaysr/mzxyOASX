part of args;

/// 战斗预设下拉框（任务设置里的「战斗配置」）
///
/// 为什么不用普通 enum：
/// 预设是「脚本实例自己的数据」（可以随便新建/删除），不是 schema 里能写死的枚举，
/// 所以选项在运行时从 `GET /battle/presets` 拉。
/// 值存的是预设 id，默认是系统预设（default）。
class BattlePresetPicker extends StatefulWidget {
  final String config;
  final String value;
  final ValueChanged<String> onChanged;

  const BattlePresetPicker({
    required this.config,
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  State<BattlePresetPicker> createState() => _BattlePresetPickerState();
}

class _BattlePresetPickerState extends State<BattlePresetPicker> {
  List<_BattlePresetOption> _presets = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiClient().getBattlePresets(widget.config);
      final list = (json['presets'] as List?) ?? const [];
      final presets = <_BattlePresetOption>[];
      for (final item in list) {
        final map = (item as Map).cast<String, dynamic>();
        presets.add(_BattlePresetOption(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
        ));
      }
      if (mounted) {
        setState(() {
          _presets = presets;
          _loading = false;
        });
      }
    } catch (e) {
      printError(info: 'load battle presets failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 140,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final presets = _presets.where((preset) => preset.id.isNotEmpty).toList();
    if (presets.isEmpty) {
      return Text('battle_no_preset'.tr,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall);
    }
    // 旧配置里可能存着空串（以前的「跟随全局」），这里显示成系统预设，
    // 用户下次改动时才会真正写回 id。
    final ids = presets.map((preset) => preset.id).toList();
    final value = ids.contains(widget.value)
        ? widget.value
        : (ids.contains('default') ? 'default' : ids.first);
    return DropdownButton<String>(
      isExpanded: true,
      value: value,
      items: [
        for (final preset in presets)
          DropdownMenuItem<String>(
            value: preset.id,
            child: Text(preset.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (selected) => widget.onChanged(selected ?? ''),
    );
  }
}

class _BattlePresetOption {
  final String id;
  final String name;

  const _BattlePresetOption({required this.id, required this.name});
}
