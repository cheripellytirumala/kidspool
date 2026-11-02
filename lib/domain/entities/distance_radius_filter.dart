import 'package:equatable/equatable.dart';

class DistanceRadiusFilter extends Equatable {
  const DistanceRadiusFilter({required this.radius});

  final int radius;

  @override
  List<Object?> get props => [radius];
}
