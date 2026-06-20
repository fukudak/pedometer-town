import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local_storage.dart';
import 'services/health_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  final healthService = HealthService(storage: storage);
  await healthService.configure();

  runApp(PedometerTownApp(prefs: prefs, healthService: healthService));
}
