part of args;

class ArgsController extends GetxController {
  final groups = Rx<List<GroupsModel>>([]);
  final groupsName = Rx<List<String>>([]);
  final groupsData = Rx<Map<String, GroupsModel>>({});
  /// 字段条件显示变化时自增，让 Args 重新构建
  final formRevision = 0.obs;

  @override
  void onInit() {
    // loadGroups();
    super.onInit();
  }

  void touch() => formRevision.value++;

  /// 根据 visible_when 判断字段是否显示
  bool isVisible(ArgumentModel model) {
    final condition = model.visibleWhen;
    if (condition == null || condition.isEmpty) {
      return true;
    }
    switch (condition) {
      case 'world_boss_dual':
        return _worldBossDual();
      default:
        return true;
    }
  }

  /// 世界首领：同一时刻是否勾选了 >=2 个首领
  bool _worldBossDual() {
    final counts = <String, int>{};
    for (final group in groupsData.value.values) {
      for (final item in group.members) {
        if (item is! ArgumentModel) {
          continue;
        }
        final match = RegExp(r'^time_(\d{2})$').firstMatch(item.title);
        if (match == null || item.value != true) {
          continue;
        }
        final hour = match.group(1)!;
        counts[hour] = (counts[hour] ?? 0) + 1;
      }
    }
    return counts.values.any((count) => count >= 2);
  }

  void loadModel(Map<String, dynamic> json) {
    groups.value = [];
    json.forEach((key, value) {
      groups.value.add(GroupsModel(groupName: key, members: value));
    });
  }

  void loadModelfromStr(String json) {
    loadModel(jsonDecode(json));
  }

  /// 加载groups数据
  Future<void> loadGroups({String config = "", String task = ""}) async {
    // 清空缓存数据
    groupsName.value = [];
    groupsData.value = {};
    List<String> groupsNameTemp = [];

    var json = await ApiClient().getScriptTask(config, task);
    // 更新groupsData
    // 更新groupsName
    for (var entry in json.entries) {
      groupsNameTemp.add(entry.key);
      List<ArgumentModel> arguments = [];
      for (var argument in entry.value) {
        arguments.add(ArgumentModel.fromJson(argument));
      }
      groupsData.value[entry.key] =
          GroupsModel(groupName: entry.key, members: arguments);
    }
    groupsName.value = groupsNameTemp;
  }

  Future<void> setArgument(String? config, String? task, String? group,
      String argument, String type, var value) async {
    if (config == null || task == null || group == null) {
      return;
    }
    if (config.isEmpty || task.isEmpty || group.isEmpty) {
      NavCtrl navCtrl = Get.find();
      config = navCtrl.selectedScript.value;
      task = navCtrl.selectedMenu.value;
    }
    await ApiClient().putScriptArg(config, task, group, argument, type, value);
    printInfo(
        info:
            "setArgument config: $config, task: $task, group: $group, argument: $argument, value: $value");
  }
}

class GroupsModel {
  final String groupName;
  List<dynamic> members;

  /// 把 json对象转化为 model
  GroupsModel({required this.groupName, required this.members});

  String getGroupName() => groupName;
}

class ArgumentModel {
  final String title;
  dynamic value;
  final String type;

  final String? description;

  final List<String>? enumEnum;
  final dynamic minimum;
  final dynamic maximum;
  final dynamic defaultValue;
  /// 条件显示标记（后端 visible_when）
  final String? visibleWhen;

  ArgumentModel(
    this.enumEnum,
    this.minimum,
    this.maximum,
    this.defaultValue,
    this.description, {
    required this.title,
    required this.value,
    required this.type,
    this.visibleWhen,
  });

  factory ArgumentModel.fromJson(Map<String, dynamic> json) {
    return ArgumentModel(
        List<String>.from(json["enumEnum"]?.map((x) => x) ?? []),
        json['minimum'],
        json['maximum'],
        json['defaultValue'],
        json['description'],
        title: json['name'] as String,
        value: json['value'],
        type: json['type'] as String,
        visibleWhen: json['visible_when'] as String?);
  }

  set setValue(dynamic newValue) => value = newValue;
}
