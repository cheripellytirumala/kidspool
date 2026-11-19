import 'package:flutter/material.dart';

import '../../../auth/presentation/screens/vehicle_details_screen.dart';
import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../data/repositories/my_car_repository.dart';
import '../../domain/entities/my_car.dart';
import 'profile_row.dart';

/// Profile › Driving › "My car": how many seats the car has. Ride requests
/// only reach drivers with room for the kids.
class MyCarRow extends StatefulWidget {
  const MyCarRow({super.key});

  @override
  State<MyCarRow> createState() => _MyCarRowState();
}

class _MyCarRowState extends State<MyCarRow> {
  final MyCarRepository _repo = sl<MyCarRepository>();
  MyCar? _car;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.get();
    if (!mounted) return;
    setState(() {
      _car = result.toNullable();
      _loaded = true;
    });
  }

  /// The full "Your vehicle" screen, then the row shows what was saved.
  Future<void> _edit() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.vehicleDetails,
      arguments: const VehicleDetailsArgs(fromProfile: true),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final car = _car;
    return ProfileRow(
      icon: const Icon(Icons.directions_car_outlined, size: 22),
      title: 'My car',
      subtitle: !_loaded
          ? 'Loading…'
          : car == null
          ? 'Add your car and its seats'
          : [car.title, car.summary].where((p) => p.isNotEmpty).join(' · '),
      onTap: _edit,
    );
  }
}
