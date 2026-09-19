import 'package:get/get.dart';

import '../../data/models/article.dart';
import 'reader_controller.dart';

class ReaderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReaderController(Get.arguments as ArticleSummary));
  }
}
