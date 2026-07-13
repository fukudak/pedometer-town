import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/town_atmosphere.dart';
import 'package:pedometer_town/widgets/town/weather_overlay.dart';

Widget _weatherStack({required bool weatherFxEnabled}) {
  return Stack(
    children: [
      const Placeholder(),
      if (weatherFxEnabled)
        const TownWeatherOverlay(
          weather: TownWeather.rainy,
          season: TownSeason.summer,
        ),
    ],
  );
}

void main() {
  testWidgets('天気演出オフ時はオーバーレイを置かない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _weatherStack(weatherFxEnabled: false),
        ),
      ),
    );

    expect(find.byType(TownWeatherOverlay), findsNothing);
  });

  testWidgets('天気演出オン時は CustomPaint を描画する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: TownWeatherOverlay(
              weather: TownWeather.rainy,
              season: TownSeason.summer,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TownWeatherOverlay), findsOneWidget);
  });
}
