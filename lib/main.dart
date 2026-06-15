import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/health_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final healthService = HealthService();
  await healthService.configure();

  final prefs = await SharedPreferences.getInstance();

  runApp(PedometerTownApp(prefs: prefs, healthService: healthService));
}
