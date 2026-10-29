/// 战斗预设的数据模型（对应后台 /battle/catalog 的返回）
///
/// 说明：
/// - 预设分两种：内建「默认预设」（builtin=true，不可修改）和用户预设；
/// - `order` 一定是 20 条（含被禁用的，位置不丢），`disabled` 是本预设不释放的技能；
/// - 实际开战时是「顺序去掉 disabled」再按识别结果排。
class BattleClass {
  final String id;
  final String name;
  final String description;
  final String color;

  const BattleClass({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#888888',
  });

  factory BattleClass.fromJson(Map<String, dynamic> json) {
    return BattleClass(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? '#888888',
    );
  }
}

class BattleSkill {
  final String id;
  final String classId;
  final String className;
  final String name;
  final String description;
  final String iconUrl;
  final double cooldown;
  final int defaultPriority;

  const BattleSkill({
    required this.id,
    required this.classId,
    required this.className,
    required this.name,
    this.description = '',
    this.iconUrl = '',
    this.cooldown = 0,
    this.defaultPriority = 0,
  });

  factory BattleSkill.fromJson(Map<String, dynamic> json) {
    return BattleSkill(
      id: json['id']?.toString() ?? '',
      classId: json['class']?.toString() ?? '',
      className: json['className']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
      cooldown: (json['cooldown'] as num?)?.toDouble() ?? 0,
      defaultPriority: (json['default_priority'] as num?)?.toInt() ?? 0,
    );
  }
}

class BattlePreset {
  final String id;
  final String name;
  List<String> order;
  List<String> disabled;
  final bool builtin;

  BattlePreset({
    required this.id,
    required this.name,
    List<String>? order,
    List<String>? disabled,
    this.builtin = false,
  })  : order = order ?? <String>[],
        disabled = disabled ?? <String>[];

  factory BattlePreset.fromJson(Map<String, dynamic> json) {
    return BattlePreset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      order: (json['order'] as List?)?.map((e) => e.toString()).toList() ?? [],
      disabled:
          (json['disabled'] as List?)?.map((e) => e.toString()).toList() ?? [],
      builtin: json['builtin'] == true,
    );
  }

  BattlePreset copyWith({
    String? name,
    List<String>? order,
    List<String>? disabled,
  }) {
    return BattlePreset(
      id: id,
      name: name ?? this.name,
      order: order ?? List<String>.of(this.order),
      disabled: disabled ?? List<String>.of(this.disabled),
      builtin: builtin,
    );
  }

  bool isDisabled(String skillId) => disabled.contains(skillId);

  int get enabledCount => order.length - disabled.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'disabled': disabled,
      };
}

/// 技能位信息（7 个），给「识别结果」面板用
class BattleSlotInfo {
  final int index;
  final String name;
  final List<int> region;

  const BattleSlotInfo({
    required this.index,
    required this.name,
    this.region = const [],
  });

  factory BattleSlotInfo.fromJson(Map<String, dynamic> json) {
    return BattleSlotInfo(
      index: (json['index'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      region: (json['region'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const [],
    );
  }
}

class BattleCatalog {
  final String config;
  final List<BattleClass> classes;
  final List<BattleSkill> skills;
  final List<BattlePreset> presets;
  final List<BattleSlotInfo> slots;
  final Map<String, dynamic> common;
  final List<String> defaultOrder;
  final double defaultThreshold;

  const BattleCatalog({
    required this.config,
    required this.classes,
    required this.skills,
    required this.presets,
    required this.slots,
    required this.common,
    required this.defaultOrder,
    required this.defaultThreshold,
  });

  factory BattleCatalog.fromJson(Map<String, dynamic> json) {
    final defaults = (json['defaults'] as Map?)?.cast<String, dynamic>() ?? {};
    return BattleCatalog(
      config: json['config']?.toString() ?? '',
      classes: (json['classes'] as List? ?? [])
          .map((e) => BattleClass.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      skills: (json['skills'] as List? ?? [])
          .map((e) => BattleSkill.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      presets: (json['presets'] as List? ?? [])
          .map((e) => BattlePreset.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      slots: (json['slots'] as List? ?? [])
          .map((e) => BattleSlotInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      common: (json['common'] as Map?)?.cast<String, dynamic>() ?? {},
      defaultOrder:
          (defaults['order'] as List? ?? []).map((e) => e.toString()).toList(),
      defaultThreshold: (defaults['threshold'] as num?)?.toDouble() ?? 0.72,
    );
  }

  BattleSkill? skill(String id) {
    for (final skill in skills) {
      if (skill.id == id) return skill;
    }
    return null;
  }

  BattlePreset? preset(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// 按顺序拿到 [BattleSkill]，顺序里有不认识的 id 就跳过
  List<BattleSkill> orderedSkills(List<String> order) {
    return order.map(skill).whereType<BattleSkill>().toList();
  }
}
