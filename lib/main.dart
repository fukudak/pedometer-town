import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local_storage.dart';
import 'services/health_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  // 前回の歩数同期が複数キーへの保存途中で終了していた場合、UIが状態を
  // 読み込む前にジャーナルから確定状態へ復旧する。
  try {
    await storage.recoverPendingEnergySync();
  } catch (_) {
    // 壊れた保存データ等で復旧できない場合も起動は継続し、次回同期時に再試行する。
  }
  try {
    await storage.recoverPendingInvestment();
  } catch (_) {
    // 投入の復旧だけに失敗しても起動は継続する。ジャーナルは削除せず残る。
  }

  final healthService = HealthService(storage: storage);
  try {
    await healthService.configure();
  } catch (_) {
    // configure 失敗時もアプリは続行する。同期時に HealthServiceException として処理される。
  }

  runApp(PedometerTownApp(prefs: prefs, healthService: healthService));
}
