import '../../core/utils/json_parser.dart';

class DistanceRadiusFilterModel {
  const DistanceRadiusFilterModel({this.radius});

  final int? radius;

  factory DistanceRadiusFilterModel.fromJson(Map<String, dynamic> json) {
    return DistanceRadiusFilterModel(radius: json.readInt('radius'));
  }

  Map<String, dynamic> toJson() => {'radius': radius};
}
