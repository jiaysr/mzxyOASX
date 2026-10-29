import 'package:get/get.dart';
import 'package:oasx/service/script_service.dart';

import 'package:oasx/views/nav/view_nav.dart';
import 'package:oasx/views/args/args_view.dart';
import 'package:oasx/controller/battle/battle_controller.dart';

class LayoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<NavCtrl>(permanent: true, NavCtrl()); // 全局唯一的
    Get.lazyPut(fenix: true, () => ArgsController()); // 全局唯一的
    // 战斗菜单是独立页面，用自己的控制器（不进 args 的通用表单）
    Get.lazyPut(fenix: true, () => BattleController());
    Get.putAsync(() async => ScriptService(), permanent: true);
  }
}
