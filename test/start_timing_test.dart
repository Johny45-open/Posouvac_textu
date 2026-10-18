import 'package:flutter_test/flutter_test.dart';
import 'package:posouvac_textu/app_strings.dart';
import 'package:posouvac_textu/player_page.dart';

void main() {
  group('beatIntervalMsForBpm — odvození odpočtu z efektivního BPM', () {
    test('120 BPM bez multiplikéru → 500 ms', () {
      expect(beatIntervalMsForBpm(120.0), 500);
    });
    test('90 BPM → 667 ms', () {
      expect(beatIntervalMsForBpm(90.0), 667);
    });
    test('150 BPM → 400 ms', () {
      expect(beatIntervalMsForBpm(150.0), 400);
    });
    test('75 BPM → 800 ms', () {
      expect(beatIntervalMsForBpm(75.0), 800);
    });
    test('180 BPM → 333 ms', () {
      expect(beatIntervalMsForBpm(180.0), 333);
    });
    test('efektivní BPM = base * multiplier (120 * 1.1 = 132 → 455 ms)', () {
      expect(beatIntervalMsForBpm(120.0 * 1.1), 455);
    });
    test('pojistky: nulové BPM a extrémy', () {
      expect(beatIntervalMsForBpm(0), 500);
      expect(beatIntervalMsForBpm(-10), 500);
      // 30 BPM by bylo 2000 ms → clamp na 1500; 400 BPM by bylo 150 ms → clamp na 250
      expect(beatIntervalMsForBpm(30.0), 1500);
      expect(beatIntervalMsForBpm(400.0), 250);
    });
  });

  group('start cue AppStrings', () {
    test('TEĎ je krátké a jednoznačné', () {
      expect(AppStrings.startCueNow, 'TEĎ');
    });
    test('odpočet má vlastní rušící label', () {
      expect(AppStrings.playerCountdownCancelLabel.isNotEmpty, true);
    });
    test('GO hláška obsahuje TEĎ', () {
      expect(AppStrings.playerGoAnnouncement.contains('TEĎ'), true);
    });
  });
}
