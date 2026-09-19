import 'package:get/get.dart';

import '../../modules/home/home_view.dart';
import '../../modules/reader/reader_binding.dart';
import '../../modules/reader/reader_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
    ),
    GetPage(
      name: Routes.reader,
      page: () => const ReaderView(),
      binding: ReaderBinding(),
      transition: Transition.cupertino,
    ),
  ];
}
