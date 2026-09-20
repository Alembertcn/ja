import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeState extends Equatable {
  const HomeState({this.tabIndex = 0});

  final int tabIndex;

  @override
  List<Object?> get props => [tabIndex];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  void changeTab(int index) => emit(HomeState(tabIndex: index));
}
