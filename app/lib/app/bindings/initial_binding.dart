import 'package:get/get.dart';

import '../../modules/home/home_controller.dart';
import '../../modules/library/library_controller.dart';
import '../../modules/profile/profile_controller.dart';

/// 首屏依赖。列表 Controller 常驻，切到「我的」再切回来不用重新拉。
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController(), permanent: true);
    Get.put(LibraryController(), permanent: true);
    Get.lazyPut(() => ProfileController(), fenix: true);
  }
}
