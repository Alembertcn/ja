import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../library/library_view.dart';
import '../plan/plan_view.dart';
import '../player/player_bar.dart';
import '../profile/profile_view.dart';
import 'home_cubit.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(
            index: state.tabIndex,
            children: const [LibraryView(), PlanView(), ProfileView()],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlayerBar.mini(),
              NavigationBar(
                selectedIndex: state.tabIndex,
                onDestinationSelected: context.read<HomeCubit>().changeTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '课文',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: '计划',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '我的',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
