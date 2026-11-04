library args;

// import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:get/get.dart';
import 'package:oasx/views/nav/view_nav.dart';
import 'package:styled_widget/styled_widget.dart';
import 'dart:convert';
import 'package:expansion_tile_group/expansion_tile_group.dart';
import 'dart:async';

import 'package:oasx/api/api_client.dart';

import '../../config/translation/i18n_content.dart';

part './group_view.dart';
part './date_time_picker.dart';
part './battle_preset_picker.dart';
part '../../controller/args/args_controller.dart';

class Args extends StatelessWidget {
  const Args({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<ArgsController>(builder: (controller) {
      // 订阅条件显示变化：勾选/取消同一时刻的 boss 时重建字段列表
      controller.formRevision.value;
      return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: ExpansionTileGroup(
                      spaceBetweenItem: 10, children: _childrenGroup(context))
                  .constrained(maxWidth: 700, minWidth: 100))
          .alignment(Alignment.topCenter);
    });
  }

  List<ExpansionTileItem> _childrenGroup(BuildContext context) {
    ArgsController controller = Get.find();
    return controller.groupsName.value
        .map((name) => ExpansionTileItem(
              initiallyExpanded: true,
              isHasTopBorder: false,
              isHasBottomBorder: false,
              // collapsedBorderColor: Theme.of(context).colorScheme.secondaryContainer,
              // expendedBorderColor: Theme.of(context).colorScheme.outline,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.24),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              title: Text(name.tr),
              children: _children(name),
            ))
        .toList();
  }

  List<Widget> _children(String groupName) {
    ArgsController controller = Get.find();
    GroupsModel groupsModel = controller.groupsData.value[groupName]!;
    List<Widget> result = [const Divider()];
    for (int i = 0; i < groupsModel.members.length; i++) {
      final member = groupsModel.members[i];
      if (member is ArgumentModel && !controller.isVisible(member)) {
        continue;
      }
      result.add(ArgumentView(
        setArgument: controller.setArgument,
        getGroupName: groupsModel.getGroupName,
        index: i,
      ));
    }
    return result;
  }
}

class ArgumentView extends StatefulWidget {
  final void Function(String? config, String? task, String? group,
      String argument, String type, dynamic value) setArgument;
  final String Function() getGroupName;
  final int index;

  const ArgumentView(
      {required this.setArgument,
      required this.getGroupName,
      required this.index,
      Key? key})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ArgumentViewState createState() => _ArgumentViewState();
}

class _ArgumentViewState extends State<ArgumentView> {
  Timer? timer;
  bool landscape = true;
  // 数值输入越界时的行内错误（null = 正常）
  String? numberError;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  ArgumentModel get model {
    ArgsController controller = Get.find();
    GroupsModel? groupsModel =
        controller.groupsData.value[widget.getGroupName()];
    return groupsModel!.members[widget.index];
  }

  @override
  Widget build(BuildContext context) {
    landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _title(),
          ),
          _form(),
        ],
      ).padding(bottom: 8);
    } else {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_title(), _form()]).padding(bottom: 8);
    }
    // return LayoutBuilder(builder: (context, constraints) {
    //   if (constraints.maxWidth >= 350) {
    //     return Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Expanded(
    //           child: _title(),
    //         ),

    //         // const Spacer(),
    //         _form(),
    //       ],
    //     );
    //   } else {
    //     return Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [_title(), _form()]);
    //   }
    // });
  }

  Widget _title() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(
        model.title.tr,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (model.description != null && model.description!.isNotEmpty)
        SelectableText(
          model.description!.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ]);
  }

  Widget _form() {
    return switch (model.type) {
      "boolean" => Checkbox(value: model.value, onChanged: onCheckboxChanged)
          .alignment(Alignment.centerLeft)
          .constrained(width: landscape ? 200 : null),
      "string" => TextFormField(
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onStringChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "multi_line" => TextFormField(
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: null,
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onStringChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "number" => _numberField(isInteger: false),
      "integer" => _numberField(isInteger: true),
      "enum" => DropdownButton<String>(
          isExpanded: !landscape,
          value: model.value.toString(),
          items: model.enumEnum!
              .map<DropdownMenuItem<String>>((e) => DropdownMenuItem(
                  value: e.toString(),
                  child: Text(
                    e.toString().tr,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ).constrained(width: landscape ? 177 : null)))
              .toList(),
          onChanged: onEnumChanged,
        ),
      "date_time" => DateTimePicker(
          value: model.value,
          onChange: onDateTimeChanged,
        ).constrained(width: landscape ? 200 : null),
      "time_delta" => TimeDeltaPicker(
          value: ensureTimeDeltaString(model.value),
          onChange: onTimeDeltaChanged,
        ).constrained(width: landscape ? 200 : null),
      "time" => TimePicker(
          value: model.value,
          onChange: onTimeChanged,
        ).constrained(width: landscape ? 200 : null),
      // 战斗预设：选项来自 /battle/presets（预设是每个脚本实例自己的，不能写成静态 enum）
      "battle_preset" => BattlePresetPicker(
          config: Get.find<NavCtrl>().selectedScript.value,
          value: (model.value ?? '').toString(),
          onChanged: onBattlePresetChanged,
        ).constrained(width: landscape ? 220 : null),
      _ =>
        Text(model.value.toString()).constrained(width: landscape ? 200 : null)
    };
  }

  Widget _numberField({required bool isInteger}) {
    return TextFormField(
      keyboardType: TextInputType.numberWithOptions(
          signed: true, decimal: !isInteger),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            RegExp(isInteger ? '[-0-9]' : '[-0-9.]')),
      ],
      initialValue: model.value.toString(),
      decoration: InputDecoration(
        isDense: true,
        helperText: model.rangeHint,
        errorText: numberError,
      ),
      onChanged: (value) {
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 1000),
            () => _submitNumber(value, isInteger: isInteger));
      },
    ).constrained(width: landscape ? 200 : null);
  }

  void onCheckboxChanged(bool? value) {
    setState(() {
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'boolean', value);
      model.value = value;
    });
    // 时间勾选变化会影响「同时段双 boss」条件字段的显隐
    Get.find<ArgsController>().touch();
    showSnakbar(value);
  }

  void onStringChanged(String? value) {
    widget.setArgument(
        "", "", widget.getGroupName(), model.title, 'string', value);
    showSnakbar(value);
  }

  void onNumberChanged(String? value) =>
      _submitNumber(value, isInteger: false);

  void onIntegerChanged(String? value) =>
      _submitNumber(value, isInteger: true);

  void _submitNumber(String? value, {required bool isInteger}) {
    if (!mounted) return;
    final number =
        isInteger ? int.tryParse(value ?? '') : double.tryParse(value ?? '');
    // 空输入 / 还没输完：先不提交，等用户继续输入
    if (number == null) {
      if (numberError != null) {
        setState(() => numberError = null);
      }
      return;
    }
    if (!model.isInRange(number)) {
      setState(() {
        numberError = '${I18n.value_out_of_range.tr}: ${model.rangeHint}';
      });
      return;
    }
    if (numberError != null) {
      setState(() => numberError = null);
    }
    widget.setArgument("", "", widget.getGroupName(), model.title,
        isInteger ? 'integer' : 'number', value);
    showSnakbar(value);
  }

  void onEnumChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'enum', value);
    });
    showSnakbar(value);
  }

  void onDateTimeChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'date_time', value);
    });
    showSnakbar(value);
  }

  void onTimeDeltaChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'time_delta', value);
    });
    showSnakbar(value);
  }

  void onTimeChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'time', value);
    });
    showSnakbar(value);
  }

  /// 战斗配置：存预设 id（空串 = 跟随全局）
  void onBattlePresetChanged(String value) {
    setState(() {
      model.value = value;
      widget.setArgument(
          "", "", widget.getGroupName(), model.title, 'string', value);
    });
    showSnakbar(value.isEmpty ? 'battle_preset_default'.tr : value);
  }

// -----------------------------------------------------------------------------
  void showSnakbar(dynamic value) {
    Get.snackbar(I18n.setting_saved.tr, "$value",
        duration: const Duration(seconds: 1));
  }
}
