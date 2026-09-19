import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../library/library_view.dart';
import '../profile/profile_view.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final index = controller.tabIndex.value;
      return Scaffold(
        body: IndexedStack(
          index: index,
          children: const [LibraryView(), ProfileView()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: controller.changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: '课文',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      );
    });
  }
}
